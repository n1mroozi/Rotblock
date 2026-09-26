//
//  AllowedHourLimitTests.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
import XCTest

@testable import Rotblock

final class AllowedHourLimitTests: LimitTestCase {
  func testAllowedHourPreset_hasExpectedWindow() {
    let preset = LimitTestFixtures.allowedHourPreset(sh: 8, sm: 30, eh: 17, em: 15)

    assertCommonPresetShape(preset, expected: .allowedHour)
    XCTAssertEqual(preset.allowedStartHour, 8)
    XCTAssertEqual(preset.allowedStartMinute, 30)
    XCTAssertEqual(preset.allowedEndHour, 17)
    XCTAssertEqual(preset.allowedEndMinute, 15)
  }

  func testAllowedHourPreset_overnightWindow_isRepresentable() {
    let preset = LimitTestFixtures.allowedHourPreset(sh: 22, sm: 0, eh: 6, em: 0)
    XCTAssertEqual(preset.allowedStartHour, 22)
    XCTAssertEqual(preset.allowedEndHour, 6)
  }

  func testAllowedHourPreset_messageLine_isNonEmpty() {
    let preset = LimitTestFixtures.allowedHourPreset(name: "Evening Lock")
    let line = ShieldConfigManager.shieldMessageLine(for: preset)
    XCTAssertFalse(line.isEmpty)
    XCTAssertTrue(line.contains("Evening Lock"))
  }
}
