//
//  TimerLimitTests.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
@testable import Rotblock
import XCTest

final class TimerLimitTests: LimitTestCase {
    func testTimerPreset_hasDuration() {
        let preset = LimitTestFixtures.timerPreset(seconds: 1200)

        assertCommonPresetShape(preset, expected: .timer)
        XCTAssertEqual(preset.timerLimitDurationSeconds, 1200)
    }

    func testTimerPreset_zeroDuration_isRepresentableForValidationLayer() {
        let preset = LimitTestFixtures.timerPreset(seconds: 0)
        XCTAssertEqual(preset.timerLimitDurationSeconds, 0)
    }

    func testTimerPreset_messageLine_isNonEmpty() {
        let preset = LimitTestFixtures.timerPreset(name: "Deep Work", seconds: 1800)
        let line = ShieldConfigManager.shieldMessageLine(for: preset)
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("Deep Work"))
    }
}
