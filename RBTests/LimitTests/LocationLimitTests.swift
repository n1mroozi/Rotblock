//
//  LocationLimitTests.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
@testable import Rotblock
import XCTest

final class LocationLimitTests: LimitTestCase {
    func testLocationPreset_hasCoordinatesRadiusAndMode() throws {
        let preset = LimitTestFixtures.locationPreset(
            lat: 51.5074,
            lon: -0.1278,
            radius: 250,
            mode: "enter"
        )

        assertCommonPresetShape(preset, expected: .location)
        let lat = try XCTUnwrap(preset.locationLatitude)
        let lon = try XCTUnwrap(preset.locationLongitude)
        let radius = try XCTUnwrap(preset.locationRadius)
        XCTAssertEqual(lat, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(lon, -0.1278, accuracy: 0.0001)
        XCTAssertEqual(radius, 250, accuracy: 0.01)
        XCTAssertEqual(preset.locationMode, "enter")
    }

    func testLocationPreset_missingCoordinates_canBeDetectedByValidation() {
        let preset = LimitTestFixtures.preset(name: "Bad", blockKinds: [.location])
        XCTAssertNil(preset.locationLatitude)
        XCTAssertNil(preset.locationLongitude)
        XCTAssertNil(preset.locationRadius)
    }

    func testLocationPreset_messageLine_isNonEmpty() {
        let preset = LimitTestFixtures.locationPreset(name: "Office")
        let line = ShieldConfigManager.shieldMessageLine(for: preset)
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.contains("Office"))
    }
}
