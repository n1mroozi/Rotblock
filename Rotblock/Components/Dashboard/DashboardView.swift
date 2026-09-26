import Combine
import DeviceActivity
import FamilyControls
import SwiftUI

/// Mirrors the context declared in `RBDeviceActivityReport/RotblockTodayReport.swift`.
/// Both sides identify the scene by the underlying string.
extension DeviceActivityReport.Context {
  static let rotblockToday = Self("RotblockToday")
}

private let dashboardDefaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

// MARK: - DashboardView

struct DashboardView: View {
  @Environment(\.rbTabSwitcher) private var switchTab
  @Environment(DeviceActivityManager.self) private var deviceActivity
  @StateObject private var presetStore = PresetStore.shared
  @State private var greetingHeadline = "A clearer day ahead."

  @AppStorage("rb.dashboard.reportScope", store: dashboardDefaults)
  private var reportScopeRaw: String = "day"

  @AppStorage("dailyLimitMinutes", store: dashboardDefaults)
  private var dashboardGoalMinutes: Int = 0

  @AppStorage(DashboardGreetingPreferences.shuffleKey, store: dashboardDefaults)
  private var greetingShuffle: Bool = true

  @AppStorage(DashboardGreetingPreferences.staticIndexKey, store: dashboardDefaults)
  private var staticGreetingIndex: Int = 0

  private var activePresets: [PresetValues] {
    deviceActivity.activePresetIDs.compactMap { presetStore.preset(id: $0) }
  }

  @State private var reportWindow: DateInterval = {
    let start = Calendar.current.startOfDay(for: Date())
    return DateInterval(start: start, end: start.addingTimeInterval(60))
  }()

  @Environment(\.scenePhase) private var scenePhase

  private var isWeeklyReport: Bool {
    reportScopeRaw == "week"
  }

  private var currentWeekInterval: DateInterval? {
    Calendar.current.dateInterval(of: .weekOfYear, for: Date())
  }

  private var reportFilter: DeviceActivityFilter {
    if isWeeklyReport, let week = currentWeekInterval {
      return DeviceActivityFilter(segment: .weekly(during: week))
    }
    return DeviceActivityFilter(segment: .daily(during: reportWindow))
  }

  private func refreshReportWindow() {
    let now = Date()
    let start = Calendar.current.startOfDay(for: now)
    // Snap end to the nearest 5-minute bucket so trivial time deltas don't churn the report.
    let bucket: TimeInterval = 5 * 60
    let snappedEnd = Date(
      timeIntervalSince1970: (now.timeIntervalSince1970 / bucket).rounded(.down) * bucket)
    let end = max(snappedEnd, start.addingTimeInterval(60))
    let newWindow = DateInterval(start: start, end: end)
    guard newWindow != reportWindow else { return }
    reportWindow = newWindow
  }

  private func refreshGreetingHeadline() {
    let lines = DashboardGreetingPreferences.effectiveGreetings(using: dashboardDefaults)
    greetingHeadline = DashboardGreetingPreferences.resolvedHeadline(
      greetings: lines,
      shuffle: greetingShuffle,
      staticIndex: staticGreetingIndex
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        topBar
          .padding(EdgeInsets(top: 8, leading: 24, bottom: 20, trailing: 24))

        greeting
          .padding(.horizontal, 24)
          .padding(.bottom, 12)

        Picker("Usage period", selection: $reportScopeRaw) {
          Text("Today").tag("day")
          Text("This week").tag("week")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)

        todayReport
          .padding(.horizontal, 24)
          .padding(.bottom, 24)

        if !activePresets.isEmpty {
          Eyebrow(text: activePresets.count == 1 ? "Active preset" : "Active presets")
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

          VStack(spacing: 8) {
            ForEach(activePresets, id: \.id) { preset in
              activePresetCard(preset)
                .padding(.horizontal, 24)
            }
          }
          .padding(.bottom, 24)
        }
      }
      .padding(.top, 12)
      .padding(.bottom, 120)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.rbIvory100.ignoresSafeArea())
    .onAppear {
      refreshGreetingHeadline()
      refreshReportWindow()
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      refreshGreetingHeadline()
      refreshReportWindow()
    }
    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
      refreshGreetingHeadline()
    }
  }

  // MARK: Top bar

  private var topBar: some View {
    HStack {
      Text(Self.dateString())
        .font(RBFont.sans(13, weight: .medium))
        .foregroundStyle(Color.rbCloud600)
    }
  }

  private var periodLabel: String {
    guard isWeeklyReport, let week = currentWeekInterval else { return "Today" }
    let cal = Calendar.current
    // week.end is exclusive (start of next week), so last day = end - 1 day
    let lastDay = cal.date(byAdding: .day, value: -1, to: week.end) ?? week.end
    let sameMonth = cal.isDate(week.start, equalTo: lastDay, toGranularity: .month)
    let startFmt = DateFormatter()
    startFmt.dateFormat = "MMM d"
    let endFmt = DateFormatter()
    endFmt.dateFormat = sameMonth ? "d" : "MMM d"
    return "\(startFmt.string(from: week.start)) – \(endFmt.string(from: lastDay))"
  }

  private var greeting: some View {
    VStack(alignment: .leading, spacing: 8) {
      Eyebrow(text: periodLabel)
      Headline(text: greetingHeadline, size: 36, weight: .regular)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var todayReport: some View {
    DeviceActivityReport(.rotblockToday, filter: reportFilter)
      .frame(maxWidth: .infinity, minHeight: 640)
      .accessibilityIdentifier("dashboard.todayReport")
  }

  // MARK: Active preset

  @ViewBuilder
  private func activePresetCard(_ preset: PresetValues) -> some View {
    let name = preset.name
    let summary = Self.summary(for: preset) ?? ""

    Button {
      switchTab(.presets)
    } label: {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.rbOrangeTint)
            .frame(width: 44, height: 44)
          Image(systemName: RBIcons.focus)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Color.rbOrange)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(name)
            .font(RBFont.sans(16, weight: .medium))
            .foregroundStyle(Color.rbSlate900)
          Text(summary)
            .font(RBFont.sans(13))
            .foregroundStyle(Color.rbCloud600)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        Text("ACTIVE")
          .font(RBFont.mono(11, weight: .regular))
          .tracking(0.4)
          .foregroundStyle(Color(.sRGB, red: 0.169, green: 0.420, blue: 0.227))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            Capsule().fill(Color(.sRGB, red: 0.902, green: 0.945, blue: 0.914))
          )
      }
      .padding(18)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.rbIvory50)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.rbIvory300, lineWidth: 1)
      )
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityIdentifier("dashboard.activePreset.\(preset.id.uuidString)")
  }

  // MARK: Helpers

  private static func dateString() -> String {
    DateFormatters.formatGreetingBannerDate()
  }

  private static func summary(for preset: PresetValues?) -> String? {
    guard let preset else { return nil }
    let selection = preset.selection
    let blocked =
      selection.applicationTokens.count
      + selection.categoryTokens.count
      + selection.webDomainTokens.count
    return "\(preset.blocksDetailSummary) · blocks \(blocked) apps"
  }
}
