//
//  OpenLimitTests.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
import XCTest
@testable import Rotblock

final class OpenLimitTests: LimitTestCase {
    func testOpenPreset_hasExpectedShape() {
        let preset = LimitTestFixtures.openPreset(count: 3, sessionSeconds: 300)

        assertCommonPresetShape(preset, expected: .open)
        XCTAssertEqual(preset.openLimitCount, 3)
        XCTAssertEqual(preset.openSessionSeconds, 300)
    }

    func testOpenPreset_allowsCountOnlyConfiguration() {
        let preset = LimitTestFixtures.openPreset(count: 4, sessionSeconds: nil)
        XCTAssertEqual(preset.openLimitCount, 4)
        XCTAssertNil(preset.openSessionSeconds)
    }

    func testOpenPreset_allowsSessionOnlyConfiguration() {
        let preset = LimitTestFixtures.openPreset(count: nil, sessionSeconds: 900)
        XCTAssertNil(preset.openLimitCount)
        XCTAssertEqual(preset.openSessionSeconds, 900)
    }
}
