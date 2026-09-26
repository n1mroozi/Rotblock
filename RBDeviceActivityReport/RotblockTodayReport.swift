// swiftlint:disable file_length
//
//  RotblockTodayReport.swift
//  RBDeviceActivityReport
//
//  DeviceActivityReport scene that renders the Today-tab hero card and
//  app breakdown in the host app's ivory/slate theme. The host embeds
//  this via `DeviceActivityReport(.rotblockToday, filter:)`.
//

import Charts
import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

// MARK: - Context

extension DeviceActivityReport.Context {
  /// The ivory-themed Today-tab report. Host and extension must agree on
  /// the underlying string identifier.
  static let rotblockToday = Self("RotblockToday")
}

// MARK: - Extension-local theme tokens

//
// The DeviceActivity extension runs out-of-process and can't share the
// host app's `RBTheme.swift`. These mirror `RBTheme` adaptive pairs so
// the embedded view matches the Today tab in light and dark mode.

private struct RbtRgbComponents {
  let r: Double
  let g: Double
  let b: Double
}

private func rbtParseHex(_ hex: String) -> RbtRgbComponents {
  let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var int: UInt64 = 0
  Scanner(string: hex).scanHexInt64(&int)
  switch hex.count {
  case 3:
    return RbtRgbComponents(
      r: Double((int >> 8) * 17) / 255,
      g: Double((int >> 4 & 0xF) * 17) / 255,
      b: Double((int & 0xF) * 17) / 255
    )
  default:
    return RbtRgbComponents(
      r: Double(int >> 16 & 0xFF) / 255,
      g: Double(int >> 8 & 0xFF) / 255,
      b: Double(int & 0xFF) / 255
    )
  }
}

private func rbtAdaptive(light: String, dark: String) -> Color {
  #if canImport(UIKit)
    return Color(
      UIColor(dynamicProvider: { trait in
        let hex = trait.userInterfaceStyle == .dark ? dark : light
        let rgb = rbtParseHex(hex)
        return UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
      }))
  #else
    let rgb = rbtParseHex(light)
    return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
  #endif
}

extension Color {
  static let rbtIvory50 = rbtAdaptive(light: "FAFAF7", dark: "1A1A18")
  static let rbtIvory100 = rbtAdaptive(light: "F5F4EF", dark: "222220")
  static let rbtIvory300 = rbtAdaptive(light: "E5E4DF", dark: "353532")
  static let rbtCloud400 = rbtAdaptive(light: "BFBFBA", dark: "5E5E5B")
  static let rbtCloud500 = rbtAdaptive(light: "91918D", dark: "8A8A86")
  static let rbtCloud600 = rbtAdaptive(light: "666663", dark: "D8D8D8")
  static let rbtSlate700 = rbtAdaptive(light: "40403E", dark: "C8C8C4")
  static let rbtSlate900 = rbtAdaptive(light: "191919", dark: "F0F0EE")

  /// Dark elevated surfaces used by the hero carousel (both appearances).
  static let rbtHeroCardFill = rbtAdaptive(light: "191919", dark: "2A2A28")
  /// Primary label on hero cards (`rbtHeroCardFill`).
  static let rbtHeroPrimary = rbtAdaptive(light: "F5F4EF", dark: "F0F0EE")
}

// MARK: - View model

struct RotblockTodayViewModel {
  struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Double
    let category: String
    let token: ApplicationToken?
    let bundleIdentifier: String?
  }

  /// Total screen time in the selected window (today or current week), in minutes.
  let totalMinutes: Double
  /// Goal in minutes: daily goal, or 7× daily when `isWeeklyScope`.
  let limitMinutes: Double
  /// Device pickup count reported by DeviceActivity for the window.
  let pickups: Int
  /// total device notifications
  let notifications: Int  // add
  /// Focus sessions activated in the report window (from the shared recent-presets log).
  let sessionsInScope: Int
  /// When true, the dashboard filter is weekly (current calendar week).
  let isWeeklyScope: Bool
  /// Top apps by duration, already sorted desc.
  let topApps: [AppUsage]

  /// 0…100 integer percent of `totalMinutes` vs `limitMinutes`.
  var percentOfLimit: Int {
    guard limitMinutes > 0 else { return 0 }
    let raw = (totalMinutes / limitMinutes) * 100
    return max(0, Int(raw.rounded()))
  }
}

/// Stable identity for per-app totals: token when available, else a fallback string.
private enum AppUsageAggKey: Hashable {
  case token(ApplicationToken)
  /// Rare: no token; bucket by category + display name to reduce accidental merges.
  case untokenized(category: String, displayName: String)
}

/// Bundle IDs for disambiguation when `approvedWithDataAccess` is active (EU + entitlement).
private func bundleIdentifierMapFromFamilyActivityDataIfAllowed() async throws -> [ApplicationToken:
  String] {
  guard AuthorizationCenter.shared.authorizationStatus == .approvedWithDataAccess else {
    return [:]
  }
  let apps = try await FamilyActivityData.shared.installedApplications
  var map: [ApplicationToken: String] = [:]
  for app in apps {
    guard let token = app.token, let bid = app.bundleIdentifier, !bid.isEmpty else { continue }
    map[token] = bid
  }
  return map
}

// MARK: - Scene

struct RotblockTodayScene: DeviceActivityReportScene {
  let context = DeviceActivityReport.Context.rotblockToday
  let content: (RotblockTodayViewModel) -> RotblockTodayView

  @MainActor
  // swiftlint:disable:next identifier_name
  func _makeScene(with id: String) -> PrimitiveAppExtensionScene? {
    body._makeScene(with: id)
  }

  // swiftlint:disable function_body_length
  func makeConfiguration(
    representing data: DeviceActivityResults<DeviceActivityData>
  ) async -> RotblockTodayViewModel {
    var durationByKey: [AppUsageAggKey: TimeInterval] = [:]
    durationByKey.reserveCapacity(64)
    var categoryByKey: [AppUsageAggKey: String] = [:]
    var displayNameByKey: [AppUsageAggKey: String] = [:]
    var tokenByKey: [AppUsageAggKey: ApplicationToken] = [:]
    var totalSeconds: TimeInterval = 0
    var totalPickups = 0
    var totalNotifications = 0

    let bundleByToken: [ApplicationToken: String]
    do {
      bundleByToken = try await bundleIdentifierMapFromFamilyActivityDataIfAllowed()
    } catch {
      bundleByToken = [:]
    }

    // Read UserDefaults AFTER the first await so the Darwin notification
    // delivering the host app's scope change has had time to propagate to
    // this extension process's in-memory UserDefaults cache.
    let suite = UserDefaults(suiteName: "group.com.n1labs.rotblock")
    let isWeeklyScope = (suite?.string(forKey: "rb.dashboard.reportScope") ?? "day") == "week"
    let storedLimit = suite?.integer(forKey: "dailyLimitMinutes") ?? 0
    let dailyGoal = Double(storedLimit > 0 ? storedLimit : 240)
    let limitMinutes = isWeeklyScope ? dailyGoal * 7 : dailyGoal

    let sessionsInScope: Int = {
      let rows = PresetSummary.load()
      if isWeeklyScope, let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) {
        return rows.filter { week.contains($0.lastUsed) }.count
      }
      return rows.filter { Calendar.current.isDateInToday($0.lastUsed) }.count
    }()

    for await activityData in data {
      for await segment in activityData.activitySegments {
        totalPickups += segment.totalPickupsWithoutApplicationActivity
        for await categoryActivity in segment.categories {
          let categoryName = categoryActivity.category.localizedDisplayName ?? "Other"
          for await appActivity in categoryActivity.applications {
            let displayName = appActivity.application.localizedDisplayName ?? "Unknown"
            let seconds = appActivity.totalActivityDuration

            let key: AppUsageAggKey
            if let token = appActivity.application.token {
              key = .token(token)
            } else {
              key = .untokenized(category: categoryName, displayName: displayName)
            }

            durationByKey[key, default: 0] += seconds
            categoryByKey[key] = categoryName
            displayNameByKey[key] = displayName
            if let token = appActivity.application.token {
              tokenByKey[key] = token
            }

            totalSeconds += seconds
            totalPickups += appActivity.numberOfPickups
            totalNotifications += appActivity.numberOfNotifications
          }
        }
      }
    }

    let topApps: [RotblockTodayViewModel.AppUsage] =
      durationByKey
      .sorted { $0.value > $1.value }
      .prefix(50)
      .map { key, seconds in
        let bundleId: String? = {
          switch key {
          case .token(let applicationToken): return bundleByToken[applicationToken]
          case .untokenized: return nil
          }
        }()
        return RotblockTodayViewModel.AppUsage(
          name: displayNameByKey[key] ?? "Unknown",
          minutes: seconds / 60,
          category: categoryByKey[key] ?? "Other",
          token: tokenByKey[key],
          bundleIdentifier: bundleId
        )
      }

    if isWeeklyScope {
      suite?.set(totalSeconds / 60, forKey: "rb.activity.totalMinutesWeek")
      suite?.set(totalPickups, forKey: "rb.activity.pickupsWeek")
      suite?.set(totalNotifications, forKey: "rb.activity.notificationsWeek")
    } else {
      suite?.set(totalSeconds / 60, forKey: "rb.activity.totalMinutesToday")
      suite?.set(totalPickups, forKey: "rb.activity.pickupsToday")
      suite?.set(totalNotifications, forKey: "rb.activity.notificationsToday")
    }
    suite?.set(Date().timeIntervalSince1970, forKey: "rb.activity.lastUpdatedAt")

    return RotblockTodayViewModel(
      totalMinutes: totalSeconds / 60,
      limitMinutes: limitMinutes,
      pickups: totalPickups,
      notifications: totalNotifications,
      sessionsInScope: sessionsInScope,
      isWeeklyScope: isWeeklyScope,
      topApps: Array(topApps)
    )
  }
  // swiftlint:enable function_body_length
}

// MARK: - View

// swiftlint:disable:next type_body_length
struct RotblockTodayView: View {
  let viewModel: RotblockTodayViewModel
  @State private var heroCardIndex = 0
  private let carouselCardHeight: CGFloat = 220
  private let slideHorizontalInset: CGFloat = 2

  private var heroPieHeader: String {
    viewModel.isWeeklyScope ? "WEEK APP USAGE" : "TODAY APP USAGE"
  }

  private var appBreakdownPeriodLabel: String {
    viewModel.isWeeklyScope ? "This week" : "Today"
  }

  private var emptyActivityCopy: String {
    viewModel.isWeeklyScope ? "No app activity in this week yet." : "No app activity yet today."
  }

  /// Distinct slice colors for the hero pie chart (readable on `rbtHeroCardFill`).
  private static let heroPieChartPalette: [Color] = [
    Color(red: 0.91, green: 0.52, blue: 0.42),
    Color(red: 0.48, green: 0.68, blue: 0.52),
    Color(red: 0.42, green: 0.58, blue: 0.92),
    Color(red: 0.78, green: 0.58, blue: 0.88),
    Color(red: 0.95, green: 0.72, blue: 0.38),
    Color(red: 0.55, green: 0.78, blue: 0.82),
  ]

  private static func heroPieSliceColor(at index: Int) -> Color {
    guard !heroPieChartPalette.isEmpty else { return Color.rbtHeroPrimary }
    return heroPieChartPalette[index % heroPieChartPalette.count]
  }

  private var ringProgressColor: Color {
    // 0...1 where 1 means 100% or higher
    let ringProgress = min(1, max(0, Double(viewModel.percentOfLimit) / 100.0))

    // Interpolate hue from green (0.33) to red (0.0)
    let hue = 0.33 * (1 - ringProgress)
    return Color(hue: hue, saturation: 0.9, brightness: 0.9)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      heroCarousel
      appBreakdown
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Hero
  private var heroCarousel: some View {
    VStack(alignment: .leading, spacing: 10) {
      TabView(selection: $heroCardIndex) {
        heroSummaryCard
          .carouselHeroPage(height: carouselCardHeight, horizontalInset: slideHorizontalInset)
          .tag(0)

        heroPieCard
          .carouselHeroPage(height: carouselCardHeight, horizontalInset: slideHorizontalInset)
          .tag(1)
      }
      .frame(height: carouselCardHeight)
      .tabViewStyle(.page(indexDisplayMode: .never))

      HStack(spacing: 8) {
        Circle()
          .fill(heroCardIndex == 0 ? Color.rbtSlate900 : Color.rbtIvory300)
          .frame(width: 7, height: 7)

        Circle()
          .fill(heroCardIndex == 1 ? Color.rbtSlate900 : Color.rbtIvory300)
          .frame(width: 7, height: 7)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 2)
    }
  }

  private var heroSummaryCard: some View {
    VStack(spacing: 18) {
      HStack(spacing: 16) {
        focusRing
        VStack(alignment: .leading, spacing: 6) {
          Text("SCREEN TIME")
            .font(.system(size: 10, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(Color.rbtCloud400)
          Text(Self.formatMinutes(viewModel.totalMinutes))
            .font(.system(size: 34, design: .serif))
            .tracking(-1)
            .foregroundStyle(Color.rbtHeroPrimary)
          HStack(spacing: 4) {
            Text("of")
              .foregroundStyle(Color.rbtCloud400)
            Text(Self.formatMinutes(viewModel.limitMinutes))
              .foregroundStyle(Color.rbtHeroPrimary)
            Text("· \(viewModel.percentOfLimit)%")
              .foregroundStyle(Color.rbtCloud400)
          }
          .font(.system(size: 12))
        }
        Spacer(minLength: 0)
      }

      Rectangle().fill(Color.rbtSlate700).frame(height: 1)

      HStack {
        miniStat(label: "Pickups", value: "\(viewModel.pickups)")
        Spacer()
        miniStat(label: "Notifications", value: "\(viewModel.notifications)")
        Spacer()
        miniStat(label: "Apps", value: "\(viewModel.topApps.count)")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(22)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.rbtHeroCardFill)
    )
  }

  private var heroPieCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(heroPieHeader)
        .font(.system(size: 10, design: .monospaced))
        .tracking(1.8)
        .foregroundStyle(Color.rbtCloud400)

      if viewModel.topApps.isEmpty {
        Text(emptyActivityCopy)
          .font(.system(size: 13))
          .foregroundStyle(Color.rbtCloud500)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        let apps = Array(viewModel.topApps.prefix(6))
        HStack(alignment: .center, spacing: 12) {
          Chart(apps) { app in
            SectorMark(
              angle: .value("Minutes", max(app.minutes, 0.1)),
              innerRadius: .ratio(0.55),
              angularInset: 1
            )
            .foregroundStyle(by: .value("App", app.name))
          }
          .chartForegroundStyleScale(
            domain: apps.map(\.name),
            range: Array(Self.heroPieChartPalette.prefix(apps.count))
          )
          .chartLegend(.hidden)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .frame(maxHeight: 160)
          .layoutPriority(1)

          VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
              HStack(alignment: .center, spacing: 8) {
                Circle()
                  .fill(Self.heroPieSliceColor(at: index))
                  .frame(width: 8, height: 8)
                Text(app.name)
                  .font(.system(size: 11))
                  .foregroundStyle(Color.rbtHeroPrimary)
                  .lineLimit(2)
                  .minimumScaleFactor(0.85)
              }
            }
          }
          .frame(minWidth: 96, maxWidth: 132, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxHeight: 160)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(22)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.rbtHeroCardFill)
    )
  }

  private var focusRing: some View {
    ZStack {
      Circle()
        .stroke(Color.rbtSlate700, lineWidth: 6)
        .frame(width: 84, height: 84)
      Circle()
        .trim(from: 0, to: min(1, CGFloat(viewModel.percentOfLimit) / 100))
        .stroke(ringProgressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .frame(width: 84, height: 84)
        .rotationEffect(.degrees(-90))
      Text("\(viewModel.percentOfLimit)%")
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color.rbtHeroPrimary)
    }
    .frame(width: 84, height: 84)
  }

  private func miniStat(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 11))
        .tracking(0.3)
        .foregroundStyle(Color.rbtCloud500)
      Text(value)
        .font(.system(size: 18, design: .monospaced))
        .foregroundStyle(Color.rbtHeroPrimary)
    }
  }

  // MARK: Breakdown

  private var appBreakdown: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("APP BREAKDOWN")
          .font(.system(size: 11, weight: .medium))
          .tracking(1.8)
          .foregroundStyle(Color.rbtCloud600)
        Spacer()
        Text(appBreakdownPeriodLabel)
          .font(.system(size: 13))
          .foregroundStyle(Color.rbtCloud600)
      }
      if viewModel.topApps.isEmpty {
        Text(emptyActivityCopy)
          .font(.system(size: 13))
          .foregroundStyle(Color.rbtCloud500)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 10)
      } else {
        let maxMinutes = viewModel.topApps.first?.minutes ?? 1
        ScrollView(.vertical, showsIndicators: false) {
          LazyVStack(spacing: 8) {
            ForEach(viewModel.topApps) { app in
              appRow(app: app, maxMinutes: maxMinutes)
            }
          }
          .padding(.vertical, 2)
        }
        .frame(minHeight: 250)  // controls scroll list height for app breakdown
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .zIndex(1)
  }

  private func appRow(app: RotblockTodayViewModel.AppUsage, maxMinutes: Double) -> some View {
    return HStack(spacing: 12) {
      Group {
        if let token = app.token {
          Label(token)
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
            .clipped()
        } else {
          Image(systemName: Self.iconForCategory(app.category))
            .font(.system(size: 22))
            .foregroundStyle(Color.rbtSlate700)
            .frame(width: 44, height: 44)
        }
      }
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(app.name)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.rbtSlate900)
            .lineLimit(1)
          Spacer()
          Text(Self.formatMinutes(app.minutes))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.rbtCloud600)
        }
        if let bid = app.bundleIdentifier {
          Text(bid)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color.rbtCloud500)
            .lineLimit(1)
        }
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: Helpers

  private static func iconForCategory(_ category: String) -> String {
    switch category.lowercased() {
    case "social networking", "social": return "person.2"
    case "entertainment": return "play.rectangle"
    case "games": return "gamecontroller"
    case "productivity & finance", "productivity": return "doc.text"
    case "news": return "newspaper"
    case "reading & reference", "reading": return "book.closed"
    case "utilities": return "wrench"
    case "health & fitness": return "heart"
    default: return "app"
    }
  }

  private static func formatMinutes(_ minutes: Double) -> String {
    let total = Int(minutes.rounded())
    let hours = total / 60
    let rem = total % 60
    if hours == 0 { return "\(total)m" }
    if rem == 0 { return "\(hours)h" }
    return "\(hours)h \(rem)m"
  }
}

extension View {
  fileprivate func carouselHeroPage(height: CGFloat, horizontalInset: CGFloat) -> some View {
    self
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .frame(height: height)
      .padding(.horizontal, horizontalInset)
  }
}
