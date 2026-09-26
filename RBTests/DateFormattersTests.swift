import XCTest
@testable import Rotblock

final class DateFormattersTests: XCTestCase {

    // MARK: - formatDuration

    func testFormatDurationZero() {
        XCTAssertEqual(DateFormatters.formatDuration(0), "0s")
    }

    func testFormatDurationSecondsOnly() {
        XCTAssertEqual(DateFormatters.formatDuration(1), "1s")
        XCTAssertEqual(DateFormatters.formatDuration(59), "59s")
    }

    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(DateFormatters.formatDuration(60), "1m 0s")
        XCTAssertEqual(DateFormatters.formatDuration(90), "1m 30s")
        XCTAssertEqual(DateFormatters.formatDuration(3599), "59m 59s")
    }

    func testFormatDurationHoursMinutesSeconds() {
        XCTAssertEqual(DateFormatters.formatDuration(3600), "1h 0m 0s")
        XCTAssertEqual(DateFormatters.formatDuration(3661), "1h 1m 1s")
        XCTAssertEqual(DateFormatters.formatDuration(7322), "2h 2m 2s")
    }

    // MARK: - formatMinutes

    func testFormatMinutesBelowOrAtSixty() {
        XCTAssertEqual(DateFormatters.formatMinutes(0), "0 min")
        XCTAssertEqual(DateFormatters.formatMinutes(1), "1 min")
        XCTAssertEqual(DateFormatters.formatMinutes(60), "60 min")
    }

    func testFormatMinutesAboveSixtyWithRemainder() {
        XCTAssertEqual(DateFormatters.formatMinutes(61), "1h 1m")
        XCTAssertEqual(DateFormatters.formatMinutes(90), "1h 30m")
        XCTAssertEqual(DateFormatters.formatMinutes(121), "2h 1m")
    }

    func testFormatMinutesExactHours() {
        XCTAssertEqual(DateFormatters.formatMinutes(120), "2h")
        XCTAssertEqual(DateFormatters.formatMinutes(180), "3h")
    }

    // MARK: - formatDurationHoursMinutes

    func testFormatDurationHoursMinutesZeroOrNegative() {
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(0), "0m")
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(-1), "0m")
    }

    func testFormatDurationHoursMinutesMinutesOnly() {
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(60), "1m")
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(30 * 60), "30m")
    }

    func testFormatDurationHoursMinutesWithHours() {
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(3600), "1h 0m")
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(5400), "1h 30m")
        XCTAssertEqual(DateFormatters.formatDurationHoursMinutes(7320), "2h 2m")
    }

    // MARK: - formatDurationShort

    func testFormatDurationShortZeroOrNegative() {
        XCTAssertEqual(DateFormatters.formatDurationShort(0), "0m")
        XCTAssertEqual(DateFormatters.formatDurationShort(-60), "0m")
    }

    func testFormatDurationShortMinutesOnly() {
        XCTAssertEqual(DateFormatters.formatDurationShort(1800), "30m")
        XCTAssertEqual(DateFormatters.formatDurationShort(59 * 60), "59m")
    }

    func testFormatDurationShortHoursOnly() {
        XCTAssertEqual(DateFormatters.formatDurationShort(3600), "1h")
        XCTAssertEqual(DateFormatters.formatDurationShort(5400), "1h")
        XCTAssertEqual(DateFormatters.formatDurationShort(7200), "2h")
    }

    // MARK: - formatWeekRange structural checks

    func testFormatWeekRangeSameMonthYear() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2024, month: 3, day: 3))!
        let end   = cal.date(from: DateComponents(year: 2024, month: 3, day: 9))!
        let result = DateFormatters.formatWeekRange(start: start, end: end)
        XCTAssertTrue(result.contains("3"), "Result '\(result)' should contain start day")
        XCTAssertTrue(result.contains("9"), "Result '\(result)' should contain end day")
        XCTAssertTrue(result.contains("-"), "Result '\(result)' should contain separator")
    }

    func testFormatWeekRangeDifferentYears() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2023, month: 12, day: 30))!
        let end   = cal.date(from: DateComponents(year: 2024, month: 1, day: 5))!
        let result = DateFormatters.formatWeekRange(start: start, end: end)
        XCTAssertTrue(result.contains("2023"), "Result '\(result)' should contain start year")
        XCTAssertTrue(result.contains("2024"), "Result '\(result)' should contain end year")
    }

    // MARK: - formatMonthRange structural checks

    func testFormatMonthRangeSameYear() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        let result = DateFormatters.formatMonthRange(start: start, end: end)
        XCTAssertTrue(result.contains("-"), "Result '\(result)' should contain separator")
    }

    func testFormatMonthRangeDifferentYears() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2023, month: 11, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        let result = DateFormatters.formatMonthRange(start: start, end: end)
        XCTAssertTrue(result.contains("2023"), "Result '\(result)' should contain start year")
        XCTAssertTrue(result.contains("2024"), "Result '\(result)' should contain end year")
    }

    // MARK: - formatDayNumber

    func testFormatDayNumberTwoDigit() {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        XCTAssertEqual(DateFormatters.formatDayNumber(date), "15")
    }

    func testFormatDayNumberSingleDigit() {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: 2024, month: 1, day: 5))!
        XCTAssertEqual(DateFormatters.formatDayNumber(date), "5")
    }
}
