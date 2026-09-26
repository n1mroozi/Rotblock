import Charts
import SwiftUI

private let dashboardDefaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

struct DashboardReportView: View {
    let viewModel: DashboardReportViewModel
    @AppStorage("dailyLimitMinutes", store: dashboardDefaults)
    private var dailyGoalMinutes: Int = 240
    private var formattedGoal: String {
        let total = max(0, dailyGoalMinutes)
        let h = total / 60
        let m = total % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var todayMinutes: Double {
        viewModel.hourlyData.reduce(0) { $0 + $1.value }
    }

    private var last7DayAverage: Double {
        guard !viewModel.dailyData.isEmpty else { return 0 }
        return viewModel.dailyData.reduce(0) { $0 + $1.value } / Double(viewModel.dailyData.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Screen Time")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.rbOutline)
                    Text(formattedTotal)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text("of \(formattedGoal)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.rbOutline)
                }
                .padding(.horizontal)
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVITY SNAPSHOT")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.rbOutline)
                    statRow(title: "Today", value: formatMinutes(todayMinutes))
                    statRow(title: "7-Day Average", value: formatMinutes(last7DayAverage))
                }
                .padding(.horizontal)
                if !viewModel.appUsages.isEmpty {
                    DashboardMostUsed(
                        apps: viewModel.appUsages.map {
                            AppUsageEntry(
                                name: $0.name,
                                minutes: $0.minutes,
                                category: $0.category,
                                token: $0.token
                            )
                        }
                    )
                    .padding(.horizontal)
                }
                DashboardActiveShields(activePreset: viewModel.activePreset)
                    .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .background(Color(hex: "131314"))
    }

    private var formattedTotal: String {
        let h = Int(viewModel.totalMinutes) / 60
        let m = Int(viewModel.totalMinutes) % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let h = total / 60
        let m = total % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.rbOutline)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .padding(.vertical, 6)
    }
}
