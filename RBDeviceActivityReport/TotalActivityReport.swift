//
//  TotalActivityReport.swift
//  DeviceActivityReport
//
//  Created by n1 on 4/9/26.
//

import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

struct DashboardReportViewModel {
    struct AppUsage: Identifiable {
        let id = UUID()
        let name: String
        let minutes: Double
        let category: String
        let token: ApplicationToken?
    }

    struct UsagePoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double // minutes
    }

    var totalMinutes: Double
    var appUsages: [AppUsage]
    var activePreset: DashboardActivePresetInfo?
    var dailyData: [UsagePoint]
    var hourlyData: [UsagePoint]
}

// MARK: - Scene

struct DashboardReportScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("DashboardScreen")
    let content: (DashboardReportViewModel) -> DashboardReportView

    @MainActor
    // swiftlint:disable:next identifier_name
    func _makeScene(with id: String) -> PrimitiveAppExtensionScene? {
        body._makeScene(with: id)
    }

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DashboardReportViewModel {
        var appDurations: [String: TimeInterval] = [:]
        var appCategories: [String: String] = [:]
        var appTokens: [String: ApplicationToken] = [:]
        var totalSeconds: TimeInterval = 0
        var dailyTotals: [Date: TimeInterval] = [:]
        var hourlyTotals: [Date: TimeInterval] = [:]
        let calendar = Calendar.current

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                let hour =
                    calendar.dateInterval(of: .hour, for: segment.dateInterval.start)?.start
                        ?? segment.dateInterval.start
                for await categoryActivity in segment.categories {
                    let categoryName = categoryActivity.category.localizedDisplayName ?? "Other"
                    for await appActivity in categoryActivity.applications {
                        let appName = appActivity.application.localizedDisplayName ?? "Unknown"
                        let seconds = appActivity.totalActivityDuration
                        appDurations[appName, default: 0] += seconds
                        appCategories[appName] = categoryName
                        if let token = appActivity.application.token {
                            appTokens[appName] = token
                        }
                        totalSeconds += seconds
                        dailyTotals[day, default: 0] += seconds
                        if calendar.isDateInToday(segment.dateInterval.start) {
                            hourlyTotals[hour, default: 0] += seconds
                        }
                    }
                }
            }
        }

        let today = calendar.startOfDay(for: Date())

        let dailyData: [DashboardReportViewModel.UsagePoint] = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = (dailyTotals[date] ?? 0) / 60
            return DashboardReportViewModel.UsagePoint(date: date, value: minutes)
        }
        let hourlyData: [DashboardReportViewModel.UsagePoint] = (0..<24).compactMap { h in
            guard let date = calendar.date(byAdding: .hour, value: h, to: today) else { return nil }
            let minutes = (hourlyTotals[date] ?? 0) / 60
            return DashboardReportViewModel.UsagePoint(date: date, value: minutes)
        }

        let appUsages = appDurations.map { name, seconds in
            DashboardReportViewModel.AppUsage(
                name: name,
                minutes: seconds / 60,
                category: appCategories[name] ?? "Other",
                token: appTokens[name]
            )
        }
        .sorted { $0.minutes > $1.minutes }
        let suite = UserDefaults(suiteName: "group.com.n1labs.rotblock")
        let activeIDsKey = "DeviceActivityManager.activePresetIDs.v1"
        let presetsKey = "saved_selection_presets"

        var activePresetInfos: [DashboardActivePresetInfo] = []
        if let data = suite?.data(forKey: activeIDsKey),
           let idStrings = try? JSONDecoder().decode([String].self, from: data),
           let presetsData = suite?.data(forKey: presetsKey),
           let presets = try? JSONDecoder().decode([PresetValues].self, from: presetsData) {
            let activeIDs = Set(idStrings.compactMap(UUID.init))
            activePresetInfos = presets
                .filter { activeIDs.contains($0.id) }
                .map { DashboardActivePresetInfo(id: $0.id, name: $0.name) }
        }
        let activePresetInfo = activePresetInfos.first
        return DashboardReportViewModel(
            totalMinutes: totalSeconds / 60,
            appUsages: appUsages,
            activePreset: activePresetInfo,
            dailyData: dailyData,
            hourlyData: hourlyData
        )
    }
}
