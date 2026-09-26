import XCTest

@testable import Rotblock

final class PresetValuesScheduleTests: XCTestCase {

  // MARK: - Weekday

  func testWeekdayCaseCount() {
    XCTAssertEqual(Weekday.allCases.count, 7)
  }

  func testWeekdayRawValues() {
    XCTAssertEqual(Weekday.sunday.rawValue, 1)
    XCTAssertEqual(Weekday.monday.rawValue, 2)
    XCTAssertEqual(Weekday.tuesday.rawValue, 3)
    XCTAssertEqual(Weekday.wednesday.rawValue, 4)
    XCTAssertEqual(Weekday.thursday.rawValue, 5)
    XCTAssertEqual(Weekday.friday.rawValue, 6)
    XCTAssertEqual(Weekday.saturday.rawValue, 7)
  }

  func testWeekdayNames() {
    XCTAssertEqual(Weekday.sunday.name, "Sunday")
    XCTAssertEqual(Weekday.monday.name, "Monday")
    XCTAssertEqual(Weekday.tuesday.name, "Tuesday")
    XCTAssertEqual(Weekday.wednesday.name, "Wednesday")
    XCTAssertEqual(Weekday.thursday.name, "Thursday")
    XCTAssertEqual(Weekday.friday.name, "Friday")
    XCTAssertEqual(Weekday.saturday.name, "Saturday")
  }

  func testWeekdayShortLabels() {
    XCTAssertEqual(Weekday.sunday.shortLabel, "Su")
    XCTAssertEqual(Weekday.monday.shortLabel, "Mo")
    XCTAssertEqual(Weekday.tuesday.shortLabel, "Tu")
    XCTAssertEqual(Weekday.wednesday.shortLabel, "We")
    XCTAssertEqual(Weekday.thursday.shortLabel, "Th")
    XCTAssertEqual(Weekday.friday.shortLabel, "Fr")
    XCTAssertEqual(Weekday.saturday.shortLabel, "Sa")
  }

  // MARK: - isActive

  func testIsActiveEmptyDays() {
    let schedule = schedule(days: [])
    XCTAssertFalse(schedule.isActive)
  }

  func testIsActiveWithDays() {
    let schedule = schedule(days: [.monday])
    XCTAssertTrue(schedule.isActive)
  }

  // MARK: - totalDurationInSeconds

  func testTotalDurationStandardWindow() {
    XCTAssertEqual(schedule(startHour: 9, endHour: 17).totalDurationInSeconds, 28800)
  }

  func testTotalDurationWithStartMinute() {
    let s = LimitPresetSchedule(
      days: [.monday], startHour: 9, startMinute: 30, endHour: 17, endMinute: 0)
    XCTAssertEqual(s.totalDurationInSeconds, 27000)
  }

  func testTotalDurationZeroWindow() {
    XCTAssertEqual(schedule(startHour: 12, endHour: 12).totalDurationInSeconds, 0)
  }

  // MARK: - summaryText

  func testSummaryTextInactive() {
    XCTAssertEqual(schedule(days: []).summaryText, "No Schedule Set")
  }

  func testSummaryTextSingleDay() {
    let s = LimitPresetSchedule(
      days: [.monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
    XCTAssertEqual(s.summaryText, "Mo · 9:00 AM - 5:00 PM")
  }

  func testSummaryTextDaysSortedByRawValue() {
    let s = LimitPresetSchedule(
      days: [.wednesday, .monday], startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
    XCTAssertTrue(
      s.summaryText.hasPrefix("Mo We ·"), "Days must be sorted sunday-first; got '\(s.summaryText)'"
    )
  }

  func testSummaryTextNoon() {
    let s = LimitPresetSchedule(
      days: [.monday], startHour: 12, startMinute: 0, endHour: 13, endMinute: 0)
    XCTAssertTrue(
      s.summaryText.contains("12:00 PM"), "Noon should format as 12:00 PM; got '\(s.summaryText)'")
  }

  func testSummaryTextMidnight() {
    let s = LimitPresetSchedule(
      days: [.monday], startHour: 0, startMinute: 0, endHour: 1, endMinute: 0)
    XCTAssertTrue(
      s.summaryText.contains("12:00 AM"),
      "Midnight should format as 12:00 AM; got '\(s.summaryText)'")
  }

  // MARK: - isTodayScheduled

  func testIsTodayScheduledTrue() {
    let monday = weekdayDate(.monday)
    let s = schedule(days: [.monday])
    XCTAssertTrue(s.isTodayScheduled(now: monday))
  }

  func testIsTodayScheduledFalse() {
    let monday = weekdayDate(.monday)
    let s = schedule(days: [.tuesday, .wednesday])
    XCTAssertFalse(s.isTodayScheduled(now: monday))
  }

  func testIsTodayScheduledEmptyDays() {
    XCTAssertFalse(schedule(days: []).isTodayScheduled())
  }

  // MARK: - olderThan15Minutes

  func testOlderThan15MinutesFresh() {
    let now = Date()
    var s = schedule(days: [.monday])
    s.updatedAt = now.addingTimeInterval(-60)
    XCTAssertFalse(s.olderThan15Minutes(now: now))
  }

  func testOlderThan15MinutesStale() {
    let now = Date()
    var s = schedule(days: [.monday])
    s.updatedAt = now.addingTimeInterval(-16 * 60)
    XCTAssertTrue(s.olderThan15Minutes(now: now))
  }

  func testOlderThan15MinutesExactBoundaryIsNotStale() {
    let now = Date()
    var s = schedule(days: [.monday])
    s.updatedAt = now.addingTimeInterval(-15 * 60)
    XCTAssertFalse(
      s.olderThan15Minutes(now: now),
      "Exactly 15 min uses strictly-greater-than; should return false")
  }

  // MARK: - Helpers

  private func schedule(
    days: [Weekday] = [.monday],
    startHour: Int = 9,
    endHour: Int = 17
  ) -> LimitPresetSchedule {
    LimitPresetSchedule(
      days: days, startHour: startHour, startMinute: 0, endHour: endHour, endMinute: 0)
  }

  private func weekdayDate(_ weekday: Weekday) -> Date {
    var comps = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
    comps.weekday = weekday.rawValue
    return Calendar.current.date(from: comps)!
  }
}
