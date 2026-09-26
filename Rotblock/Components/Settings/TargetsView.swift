import SwiftUI

extension Notification.Name {
    static let rbDailyGoalDidChange = Notification.Name("rb.dailyGoalDidChange")
}

private let dashboardDefaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

private enum DashboardDailyGoal {
    static let suiteName = "group.com.n1labs.rotblock"
    static let minutesStorageKey = "dailyLimitMinutes"

    static let minMinutes = 15.0
    static let defaultMinutes = 240
    static let maxMinutes = 960.0
    static let stepMinutes = 15.0

    static var suite: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

struct TargetsView: View {
    enum Mode {
        case settings
        case onboarding(onFinish: () -> Void)
    }

    @AppStorage(DashboardDailyGoal.minutesStorageKey, store: dashboardDefaults)
    private var storedGoalMinutes: Int = DashboardDailyGoal.defaultMinutes

    let mode: Mode

    @State private var goalMinutes: Double = .init(DashboardDailyGoal.defaultMinutes)

    @State private var showingSavedConfirmation = false

    private var formattedGoal: String {
        Self.describeMinutes(Int(goalMinutes.rounded()))
    }

    private var percentPreview: Int {
        let goal = Int(goalMinutes.rounded())
        guard goal > 0 else { return 0 }
        let exampleUsedMinutes = 120
        return min(100, max(0, Int((Double(exampleUsedMinutes) / Double(goal)) * 100)))
    }

    private var isSettingsMode: Bool {
        if case .settings = mode { return true }
        return false
    }

    private var contextDescription: String {
        let mins = Int(goalMinutes.rounded())
        switch mins {
        case ..<30: return "a quick coffee break"
        case 30..<60: return "a short lunch"
        case 60..<90: return "a lunch hour"
        case 90..<150: return "a long lunch"
        case 150..<270: return "a long lunch & the morning commute"
        case 270..<360: return "a half day of leisure"
        case 360..<480: return "most of a work morning"
        case 480..<600: return "a full work day"
        default: return "most of your waking hours"
        }
    }

    @ViewBuilder private var timeFigure: some View {
        let total = Int(goalMinutes.rounded())
        let hours = total / 60
        let mins = total % 60
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            if hours > 0 {
                Text("\(hours)")
                    .font(RBFont.frauncesItalic(72))
                Text("h")
                    .font(RBFont.frauncesItalic(36))
            }
            if mins > 0 {
                Text(hours > 0 ? " \(mins)" : "\(mins)")
                    .font(RBFont.frauncesItalic(hours > 0 ? 48 : 72))
                Text("m")
                    .font(RBFont.frauncesItalic(hours > 0 ? 28 : 36))
            }
        }
        .foregroundStyle(Color.white)
    }

    var body: some View {
        ZStack {
            Color.rbIvory100.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headlineBlock
                    VStack(spacing: 10) {
                        Text("DAILY LIMIT")
                            .font(RBFont.sans(10, weight: .medium))
                            .foregroundStyle(Color.rbCloud600)
                            .kerning(2)
                        timeFigure
                        Text("~ \(contextDescription)")
                            .font(RBFont.frauncesItalic(13))
                            .foregroundStyle(Color.rbCloud600)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.rbSlate900)
                    )

                    RBSlider(
                        value: $goalMinutes,
                        range: DashboardDailyGoal.minMinutes ... DashboardDailyGoal.maxMinutes,
                        step: DashboardDailyGoal.stepMinutes
                    )
                    .font(RBFont.mono(11))
                    .foregroundStyle(Color.rbCloud500)

                    Button(action: restoreDefault) {
                        Text("Restore default")
                            .font(RBFont.sans(15, weight: .medium))
                            .foregroundStyle(Color.rbCloud600)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(DashboardDailyGoal.suite == nil)
                    if isSettingsMode {
                        RBButton(title: "Save", style: .primary, icon: RBIcons.check) {
                            persist()
                            showingSavedConfirmation = true
                        }
                        .padding(.top, 6)
                    }
                    if case .onboarding(let onFinish) = mode {
                        RBButton(title: "Continue", style: .primary, icon: RBIcons.chevronRight) {
                            persist()
                            onFinish()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .overlay(alignment: .top) {
            if showingSavedConfirmation {
                Text("Daily target saved")
                    .font(RBFont.sans(14, weight: .medium))
                    .foregroundStyle(Color.rbSlate900)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.smooth) { showingSavedConfirmation = false }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar(isSettingsMode ? .automatic : .hidden, for: .navigationBar)
        .onAppear {
            let fallback = DashboardDailyGoal.defaultMinutes
            let raw = storedGoalMinutes > 0 ? storedGoalMinutes : fallback
            goalMinutes = Double(
                min(Int(DashboardDailyGoal.maxMinutes), max(Int(DashboardDailyGoal.minMinutes), raw))
            )
            // Seed the App Group default so the report extension always has a value.
            if storedGoalMinutes == 0 {
                storedGoalMinutes = fallback
            }
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Daily Budget")
            Headline(text: "How much\nis a good day?", size: 32, weight: .regular)
                .font(RBFont.sans(15))
                .foregroundStyle(Color.rbCloud600)
                .lineSpacing(3)
            Text(
                "Total time across all blocked apps. The Today screen compares your usage to this number."
            )
            .font(RBFont.sans(15))
            .foregroundStyle(Color.rbCloud600)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func persist() {
        guard dashboardDefaults != nil else { return }
        let step = DashboardDailyGoal.stepMinutes
        let snapped = Int((goalMinutes / step).rounded() * step)
        let clamped = min(
            Int(DashboardDailyGoal.maxMinutes),
            max(Int(DashboardDailyGoal.minMinutes), snapped)
        )
        storedGoalMinutes = clamped
        NotificationCenter.default.post(name: .rbDailyGoalDidChange, object: nil)
    }

    private func restoreDefault() {
        goalMinutes = Double(DashboardDailyGoal.defaultMinutes)
    }

    private static func describeMinutes(_ total: Int) -> String {
        let hours = total / 60
        let rem = total % 60
        if hours == 0 { return "\(total)m" }
        if rem == 0 { return "\(hours)h" }
        return "\(hours)h \(rem)m"
    }
}

#Preview("Settings mode") {
    NavigationStack {
        TargetsView(mode: .settings)
    }
}

#Preview("Onboarding mode") {
    NavigationStack {
        TargetsView(mode: .onboarding(onFinish: {}))
    }
}
