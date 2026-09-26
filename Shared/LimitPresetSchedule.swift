import Foundation

/// The day of the week, matching `Calendar.Component.weekday` raw values (Sunday = 1).
///
/// Marked `nonisolated` so that when this file is included in targets whose
/// default actor isolation is `MainActor`, the synthesized `Codable`/`Equatable`
/// conformances stay free of actor isolation and can be used from any context.
nonisolated enum Weekday: Int, CaseIterable, Codable, Equatable {
  case sunday = 1
  case monday
  case tuesday
  case wednesday
  case thursday
  case friday
  case saturday

  /// The full localized name (e.g. `"Monday"`).
  var name: String {
    switch self {
    case .sunday: return "Sunday"
    case .monday: return "Monday"
    case .tuesday: return "Tuesday"
    case .wednesday: return "Wednesday"
    case .thursday: return "Thursday"
    case .friday: return "Friday"
    case .saturday: return "Saturday"
    }
  }

  /// A two-character abbreviation for compact display (e.g. `"Mo"`).
  var shortLabel: String {
    switch self {
    case .sunday: return "Su"
    case .monday: return "Mo"
    case .tuesday: return "Tu"
    case .wednesday: return "We"
    case .thursday: return "Th"
    case .friday: return "Fr"
    case .saturday: return "Sa"
    }
  }
}

/// The recurrence schedule attached to a limit preset.
///
/// Defines which days of the week the preset is active and the daily time window
/// (start hour/minute → end hour/minute) during which restrictions apply.
///
/// Marked `nonisolated` so the synthesized `Codable` conformance stays free of
/// actor isolation even in targets that default to `MainActor` — important because
/// the schedule is encoded/decoded from both UI and background paths.
nonisolated struct LimitPresetSchedule: Codable, Equatable {
  /// The days on which the schedule is active. An empty array means no schedule is set.
  var days: [Weekday]

  /// The hour component of the schedule's start time (24-hour clock, 0–23).
  var startHour: Int
  /// The minute component of the schedule's start time (0–59).
  var startMinute: Int
  /// The hour component of the schedule's end time (24-hour clock, 0–23).
  var endHour: Int
  /// The minute component of the schedule's end time (0–59).
  var endMinute: Int

  /// The last time this schedule was modified. Used to detect stale schedules.
  var updatedAt: Date = Date()

  /// Whether the schedule has at least one active day.
  var isActive: Bool {
    return !days.isEmpty
  }

  /// The total duration of the scheduled window in seconds.
  ///
  /// Computed as `(endHour - startHour) * 3600 + (endMinute - startMinute) * 60`.
  ///
  /// - Note: Does not account for windows that cross midnight.
  var totalDurationInSeconds: Int {
    return (endHour - startHour) * 3600 + (endMinute - startMinute) * 60
  }

  /// A human-readable summary of the schedule (e.g. `"Mo Tu We · 9:00 AM - 5:00 PM"`).
  ///
  /// Returns `"No Schedule Set"` when `isActive` is `false`.
  var summaryText: String {
    guard isActive else { return "No Schedule Set" }

    let daysSummary =
      days
      .sorted { $0.rawValue < $1.rawValue }
      .map { $0.shortLabel }
      .joined(separator: " ")

    let start = formattedTimeString(hour24: startHour, minute: startMinute)
    let end = formattedTimeString(hour24: endHour, minute: endMinute)

    return "\(daysSummary) · \(start) - \(end)"
  }

  /// Returns `true` when today's weekday appears in `days`.
  ///
  /// - Parameters:
  ///   - now: The reference date. Defaults to `Date()`.
  ///   - calendar: The calendar used to extract the weekday component. Defaults to `.current`.
  /// - Returns: `false` when the schedule has no active days or today is not scheduled.
  func isTodayScheduled(now: Date = Date(), calendar: Calendar = .current) -> Bool {
    guard isActive else { return false }
    let currentWeekdayRaw = calendar.component(.weekday, from: now)
    guard let today = Weekday(rawValue: currentWeekdayRaw) else { return false }
    return days.contains(today)
  }

  /// Returns `true` when the schedule was last updated more than 15 minutes ago.
  ///
  /// Used to detect whether a running schedule needs to be restarted after a configuration change.
  ///
  /// - Parameter now: The reference date. Defaults to `Date()`.
  func olderThan15Minutes(now: Date = Date()) -> Bool {
    return now.timeIntervalSince(updatedAt) > 15 * 60
  }

  private func formattedTimeString(hour24: Int, minute: Int) -> String {
    var hour = hour24 % 12
    if hour == 0 { hour = 12 }
    let isPM = hour24 >= 12
    return "\(hour):\(String(format: "%02d", minute)) \(isPM ? "PM" : "AM")"
  }
}
