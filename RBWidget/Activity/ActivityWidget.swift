import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct ActivityEntry: TimelineEntry {
  let date: Date
  let totalMinutes: Double
  let goalMinutes: Double
  let pickups: Int
  let notifications: Int
  let lastUpdatedAt: Date?
}

// MARK: - Timeline Provider

struct ActivityProvider: TimelineProvider {
  func placeholder(in context: Context) -> ActivityEntry {
    ActivityEntry(
      date: Date(),
      totalMinutes: 180,
      goalMinutes: 240,
      pickups: 42,
      notifications: 18,
      lastUpdatedAt: nil
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (ActivityEntry) -> Void) {
    completion(readEntry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityEntry>) -> Void) {
    let entry = readEntry(at: Date())
    let refresh = Date().addingTimeInterval(30 * 60)
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }

  private func readEntry(at date: Date) -> ActivityEntry {
    let defaults = UserDefaults(suiteName: WidgetManager.Constants.appGroupSuite)
    let totalMinutes = defaults?.double(forKey: WidgetManager.Constants.ScreenTimeCache.totalMinutesToday) ?? 0
    let goalRaw = defaults?.integer(forKey: "dailyLimitMinutes") ?? 0
    let goalMinutes = Double(goalRaw > 0 ? goalRaw : 240)
    let pickups = defaults?.integer(forKey: WidgetManager.Constants.ScreenTimeCache.pickupsToday) ?? 0
    let notifications = defaults?.integer(forKey: WidgetManager.Constants.ScreenTimeCache.notificationsToday) ?? 0
    let epoch = defaults?.double(forKey: WidgetManager.Constants.ScreenTimeCache.lastUpdatedAt) ?? 0
    let lastUpdatedAt: Date? = epoch > 0 ? Date(timeIntervalSince1970: epoch) : nil

    return ActivityEntry(
      date: date,
      totalMinutes: totalMinutes,
      goalMinutes: goalMinutes,
      pickups: pickups,
      notifications: notifications,
      lastUpdatedAt: lastUpdatedAt
    )
  }
}

// MARK: - Widget

struct ActivityWidget: Widget {
  let kind = WidgetManager.Constants.activityWidgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ActivityProvider()) { entry in
      ActivityWidgetView(entry: entry)
    }
    .configurationDisplayName("Screen Time")
    .description("See your daily screen time at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Widget View

struct ActivityWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ActivityEntry

  private var percentOfGoal: Double {
    guard entry.goalMinutes > 0 else { return 0 }
    return min(1, entry.totalMinutes / entry.goalMinutes)
  }

  private var ringColor: Color {
    switch percentOfGoal {
    case ..<0.6: return AW.green
    case ..<0.85: return AW.amber
    default: return AW.red
    }
  }

  var body: some View {
    Group {
      if family == .systemMedium {
        mediumView
      } else {
        smallView
      }
    }
    .containerBackground(for: .widget) { AW.ivory50 }
  }

  // MARK: Small

  private var smallView: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("SCREEN TIME")
        .font(AW.mono(9))
        .tracking(1.4)
        .foregroundStyle(AW.cloud400)

      Spacer()

      progressRing
        .frame(width: 54, height: 54)

      Spacer()

      Text(formatMinutes(entry.totalMinutes))
        .font(AW.serif(22, weight: .medium))
        .foregroundStyle(AW.slate900)
        .minimumScaleFactor(0.72)
        .lineLimit(1)

      Text("of \(formatMinutes(entry.goalMinutes))")
        .font(AW.mono(10))
        .foregroundStyle(AW.cloud400)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(14)
  }

  // MARK: Medium

  private var mediumView: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 0) {
        Text("SCREEN TIME")
          .font(AW.mono(9))
          .tracking(1.4)
          .foregroundStyle(AW.cloud400)

        Spacer()

        Text(formatMinutes(entry.totalMinutes))
          .font(AW.serif(30, weight: .medium))
          .foregroundStyle(AW.slate900)
          .minimumScaleFactor(0.72)
          .lineLimit(1)

        Text("of \(formatMinutes(entry.goalMinutes))")
          .font(AW.mono(11))
          .foregroundStyle(AW.cloud400)
          .padding(.top, 3)

        progressBar
          .padding(.top, 10)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

      Divider()
        .background(AW.cloud100)

      VStack(alignment: .leading, spacing: 14) {
        miniStat(label: "Pickups", value: "\(entry.pickups)", icon: "hand.tap")
        miniStat(label: "Notifs", value: "\(entry.notifications)", icon: "bell")
        miniStat(
          label: "Goal",
          value: "\(Int((percentOfGoal * 100).rounded()))%",
          icon: "target"
        )
      }
      .frame(width: 96)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(16)
  }

  // MARK: Subviews

  private var progressRing: some View {
    ZStack {
      Circle()
        .stroke(AW.cloud100, lineWidth: 5)
      Circle()
        .trim(from: 0, to: percentOfGoal)
        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }

  private var progressBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(AW.cloud100)
          .frame(height: 4)
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(ringColor)
          .frame(width: geo.size.width * percentOfGoal, height: 4)
      }
    }
    .frame(height: 4)
  }

  private func miniStat(label: String, value: String, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .light))
        .foregroundStyle(AW.cloud400)
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 1) {
        Text(value)
          .font(AW.mono(13))
          .foregroundStyle(AW.slate900)
        Text(label)
          .font(AW.mono(8))
          .tracking(0.8)
          .textCase(.uppercase)
          .foregroundStyle(AW.cloud400)
      }
    }
  }

  // MARK: Helpers

  private func formatMinutes(_ minutes: Double) -> String {
    let total = Int(minutes.rounded())
    let h = total / 60
    let m = total % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
  }
}

// MARK: - Theme tokens

private enum AW {
  static let slate900 = Color(red: 0.098, green: 0.098, blue: 0.094)
  static let cloud400 = Color(red: 0.690, green: 0.690, blue: 0.678)
  static let cloud100 = Color(red: 0.922, green: 0.922, blue: 0.914)
  static let ivory50 = Color(red: 0.980, green: 0.980, blue: 0.969)
  static let green = Color(red: 0.180, green: 0.690, blue: 0.310)
  static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)
  static let red = Color(red: 0.878, green: 0.235, blue: 0.192)

  static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .custom("Fraunces", size: size).weight(weight)
  }

  static func mono(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .monospaced)
  }
}

// MARK: - Previews

#Preview("Small — active", as: .systemSmall) {
  ActivityWidget()
} timeline: {
  ActivityEntry(date: .now, totalMinutes: 187, goalMinutes: 240, pickups: 42, notifications: 18, lastUpdatedAt: .now)
}

#Preview("Small — over goal", as: .systemSmall) {
  ActivityWidget()
} timeline: {
  ActivityEntry(date: .now, totalMinutes: 310, goalMinutes: 240, pickups: 87, notifications: 55, lastUpdatedAt: .now)
}

#Preview("Small — no data", as: .systemSmall) {
  ActivityWidget()
} timeline: {
  ActivityEntry(date: .now, totalMinutes: 0, goalMinutes: 240, pickups: 0, notifications: 0, lastUpdatedAt: nil)
}

#Preview("Medium — active", as: .systemMedium) {
  ActivityWidget()
} timeline: {
  ActivityEntry(date: .now, totalMinutes: 187, goalMinutes: 240, pickups: 42, notifications: 18, lastUpdatedAt: .now)
}

#Preview("Medium — over goal", as: .systemMedium) {
  ActivityWidget()
} timeline: {
  ActivityEntry(date: .now, totalMinutes: 310, goalMinutes: 240, pickups: 87, notifications: 55, lastUpdatedAt: .now)
}
