//
//  PresetBlocksTests.swift
//  Rotblock
//

import XCTest

@testable import Rotblock

final class PresetBlocksTests: LimitTestCase {
  // MARK: - Legacy migration

  func testLegacyPresetDecodesSingleLimitTypeIntoBlockKinds() throws {
    // JSON shaped like a pre-blocks preset: single `limitType`, no `blockKinds`.
    let legacyJSON = """
      {
        "id": "6F1D9AA2-3A70-4E5B-9F2D-9B43A5E6C111",
        "name": "Legacy",
        "createdAt": 700000000,
        "selectionData": "",
        "limitType": "Location Limit",
        "locationLatitude": 40.7,
        "locationLongitude": -74.0,
        "locationRadius": 150
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(PresetValues.self, from: legacyJSON)
    XCTAssertEqual(decoded.blockKinds, [.location])
    XCTAssertTrue(decoded.hasBlock(.location))
    XCTAssertFalse(decoded.hasBlock(.open))
    XCTAssertEqual(decoded.locationRadius, 150)
  }

  func testLegacyShortRawValueDecodes() throws {
    let legacyJSON = """
      {
        "id": "6F1D9AA2-3A70-4E5B-9F2D-9B43A5E6C112",
        "name": "Legacy Timer",
        "createdAt": 700000000,
        "selectionData": "",
        "limitType": "timer"
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(PresetValues.self, from: legacyJSON)
    XCTAssertEqual(decoded.blockKinds, [.timer])
  }

  // MARK: - Round trip

  func testMultiBlockPresetRoundTripsThroughCodable() throws {
    let preset = LimitTestFixtures.preset(
      name: "Gym Only",
      blockKinds: [.location, .open],
      openLimitCount: 5,
      openSessionSeconds: 600,
      locationLatitude: 40.7128,
      locationLongitude: -74.0060,
      locationRadius: 200,
      locationMode: "allowed"
    )

    let data = try JSONEncoder().encode(preset)
    let decoded = try JSONDecoder().decode(PresetValues.self, from: data)

    XCTAssertEqual(decoded.blockKinds, [.location, .open])
    XCTAssertEqual(decoded.openLimitCount, 5)
    XCTAssertEqual(decoded.locationRadius, 200)
    XCTAssertEqual(decoded, preset)
  }

  func testEncodedPresetStillCarriesLegacyLimitTypeKey() throws {
    let preset = LimitTestFixtures.preset(blockKinds: [.timer, .open])
    let data = try JSONEncoder().encode(preset)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["limitType"] as? String, "Timer Limit")
  }

  // MARK: - Normalization

  func testBlockKindsDeduplicatePreservingOrder() {
    let preset = LimitTestFixtures.preset(blockKinds: [.open, .timer, .open, .timer])
    XCTAssertEqual(preset.blockKinds, [.open, .timer])
  }

  func testEmptyBlockKindsFallBackToOpen() {
    let preset = LimitTestFixtures.preset(blockKinds: [])
    XCTAssertEqual(preset.blockKinds, [.open])
  }

  // MARK: - Queries & display

  func testHasCountedOpenBlock() {
    XCTAssertTrue(LimitTestFixtures.openPreset(count: 3, sessionSeconds: nil).hasCountedOpenBlock)
    XCTAssertFalse(LimitTestFixtures.openPreset(count: nil, sessionSeconds: 600).hasCountedOpenBlock)
    XCTAssertFalse(LimitTestFixtures.timerPreset().hasCountedOpenBlock)
  }

  func testBlocksLabelJoinsKinds() {
    let preset = LimitTestFixtures.preset(blockKinds: [.location, .open])
    XCTAssertEqual(preset.blocksLabel, "Location + Opens")
  }

  func testBlocksDetailSummaryForCombinedPreset() {
    let preset = LimitTestFixtures.preset(
      blockKinds: [.location, .open],
      openLimitCount: 4,
      locationRadius: 120
    )
    XCTAssertEqual(preset.blocksDetailSummary, "Zone 120 m · 4 opens/day")
  }

  func testShieldMessageLineListsEveryBlock() {
    let preset = LimitTestFixtures.preset(
      name: "Campus",
      blockKinds: [.location, .open],
      openLimitCount: 4
    )
    let line = ShieldConfigManager.shieldMessageLine(for: preset)
    XCTAssertEqual(line, "Campus: Location limit active · Open limit 4/day")
  }
}
