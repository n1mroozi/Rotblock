//
//  ShieldConfigManager.swift
//  Rotblock
//
//  Created by n1 on 5/8/26.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import OSLog

enum ShieldConfigManager {
    private static let suiteName = "group.com.n1labs.rotblock"

    struct PresetConflict: Equatable {
        let activePresetID: UUID
        let activePresetName: String
        let conflictingApplications: Int
        let conflictingCategories: Int
        let conflictingWebDomains: Int

        var totalConflicts: Int {
            conflictingApplications + conflictingCategories + conflictingWebDomains
        }
    }

    enum ShieldTarget: Hashable {
        case application(ApplicationToken)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)
    }

    static func apply(_ preset: PresetValues) {
        for kind in preset.blockKinds {
            switch kind {
            case .open:
                applyOpenLimit(preset)
            case .timer:
                applyTimerLimit(preset)
            case .allowedHour:
                applyAllowedHours(preset)
            case .location:
                applyLocationLimit(preset)
            }
        }
    }

    static func applyOpenLimit(_ preset: PresetValues) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        if let maxOpens = preset.openLimitCount, maxOpens > 0 {
            defaults.set(maxOpens, forKey: ShieldOpenLimit.maxKey)

            if let secs = preset.openSessionSeconds, secs > 0 {
                defaults.set(max(1, Int(secs / 60)), forKey: ShieldOpenLimit.allowedTimeKey)
            } else {
                defaults.removeObject(forKey: ShieldOpenLimit.allowedTimeKey)
            }

            let today = ShieldOpenLimit.todayKey()
            if defaults.string(forKey: ShieldOpenLimit.dayKey) != today {
                defaults.set(today, forKey: ShieldOpenLimit.dayKey)
                defaults.set(0, forKey: ShieldOpenLimit.countKey)
            }

            defaults.set("open", forKey: "rb.activeLimitType")
        } else {
            defaults.removeObject(forKey: ShieldOpenLimit.maxKey)
            defaults.removeObject(forKey: ShieldOpenLimit.allowedTimeKey)
        }
    }

    static func applyTimerLimit(_ preset: PresetValues) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set("timer", forKey: "rb.activeLimitType")
    }

    static func applyAllowedHours(_ preset: PresetValues) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set("allowedHour", forKey: "rb.activeLimitType")
        defaults.set(preset.allowedStartHour ?? 9, forKey: "rb.allowed.startHour")
        defaults.set(preset.allowedStartMinute ?? 0, forKey: "rb.allowed.startMinute")
        defaults.set(preset.allowedEndHour ?? 17, forKey: "rb.allowed.endHour")
        defaults.set(preset.allowedEndMinute ?? 0, forKey: "rb.allowed.endMinute")
    }

    static func applyLocationLimit(_ preset: PresetValues) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set("location", forKey: "rb.activeLimitType")
    }

    // MARK: - Overlap and Ownership

    static func conflictsForActivation(
        candidate: PresetValues,
        against activePresets: [PresetValues]
    ) -> [PresetConflict] {
        let candidateSelection = candidate.selection

        return activePresets
            .filter { $0.id != candidate.id }
            .compactMap { activePreset in
                let activeSelection = activePreset.selection
                let appOverlap = candidateSelection.applicationTokens
                    .intersection(activeSelection.applicationTokens).count
                let categoryOverlap = candidateSelection.categoryTokens
                    .intersection(activeSelection.categoryTokens).count
                let webOverlap = candidateSelection.webDomainTokens
                    .intersection(activeSelection.webDomainTokens).count

                guard appOverlap + categoryOverlap + webOverlap > 0 else { return nil }
                return PresetConflict(
                    activePresetID: activePreset.id,
                    activePresetName: activePreset.name,
                    conflictingApplications: appOverlap,
                    conflictingCategories: categoryOverlap,
                    conflictingWebDomains: webOverlap
                )
            }
            .sorted {
                if $0.totalConflicts == $1.totalConflicts {
                    return $0.activePresetName.localizedCaseInsensitiveCompare($1.activePresetName)
                        == .orderedAscending
                }
                return $0.totalConflicts > $1.totalConflicts
            }
    }

    static func hasActivationConflict(
        candidate: PresetValues,
        against activePresets: [PresetValues]
    ) -> Bool {
        !conflictsForActivation(candidate: candidate, against: activePresets).isEmpty
    }

    static func owningPreset(
        for target: ShieldTarget,
        in activePresets: [PresetValues]
    ) -> PresetValues? {
        let matched = activePresets.filter { preset in
            let selection = preset.selection
            switch target {
            case let .application(token):
                return selection.applicationTokens.contains(token)
            case let .category(token):
                return selection.categoryTokens.contains(token)
            case let .webDomain(token):
                return selection.webDomainTokens.contains(token)
            }
        }

        return matched.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
        .first
    }

    static func owningPreset(
        for application: ApplicationToken,
        in activePresets: [PresetValues]
    ) -> PresetValues? {
        owningPreset(for: .application(application), in: activePresets)
    }

    static func owningPreset(
        for category: ActivityCategoryToken,
        in activePresets: [PresetValues]
    ) -> PresetValues? {
        owningPreset(for: .category(category), in: activePresets)
    }

    static func owningPreset(
        for webDomain: WebDomainToken,
        in activePresets: [PresetValues]
    ) -> PresetValues? {
        owningPreset(for: .webDomain(webDomain), in: activePresets)
    }

    static func shieldMessageLine(for preset: PresetValues) -> String {
        let details = preset.blockKinds.map { shieldMessageDetail(for: preset, kind: $0) }
        return "\(preset.name): \(details.joined(separator: " · "))"
    }

    /// Message fragment for a single block, without the preset-name prefix.
    static func shieldMessageDetail(for preset: PresetValues, kind: LimitType) -> String {
        switch kind {
        case .open:
            if let max = preset.openLimitCount, max > 0 {
                return "Open limit \(max)/day"
            }
            return "Open limit active"
        case .timer:
            if let duration = preset.timerLimitDurationSeconds, duration > 0 {
                let minutes = Int(duration / 60)
                if minutes > 0 {
                    return "Session limit \(minutes)m"
                }
            }
            return "Timer limit active"
        case .allowedHour:
            if
                let startHour = preset.allowedStartHour,
                let startMinute = preset.allowedStartMinute,
                let endHour = preset.allowedEndHour,
                let endMinute = preset.allowedEndMinute
            {
                return "Allowed \(timeString(hour: startHour, minute: startMinute))"
                    + " - \(timeString(hour: endHour, minute: endMinute))"
            }
            return "Allowed hours active"
        case .location:
            return "Location limit active"
        }
    }

    private nonisolated static func stablePresetOrdering(_ lhs: PresetValues, _ rhs: PresetValues) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.createdAt < rhs.createdAt
    }

    private static func timeString(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
