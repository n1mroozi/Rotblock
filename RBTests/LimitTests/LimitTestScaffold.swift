//
//  LimitTestScaffold.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
import FamilyControls
import XCTest

@testable import Rotblock

enum LimitTestFixtures {
  static func preset(
    name: String = "Test Preset",
    blockKinds: [LimitType],
    createdAt: Date = Date(),
    openLimitCount: Int? = nil,
    openSessionSeconds: Double? = nil,
    timerLimitDurationSeconds: Double? = nil,
    allowedStartHour: Int? = nil,
    allowedStartMinute: Int? = nil,
    allowedEndHour: Int? = nil,
    allowedEndMinute: Int? = nil,
    locationLatitude: Double? = nil,
    locationLongitude: Double? = nil,
    locationRadius: Double? = nil,
    locationMode: String? = nil
  ) -> PresetValues {
    PresetValues(
      name: name,
      createdAt: createdAt,
      selection: FamilyActivitySelection(),
      blockKinds: blockKinds,
      timerLimitDurationSeconds: timerLimitDurationSeconds,
      allowedStartHour: allowedStartHour,
      allowedStartMinute: allowedStartMinute,
      allowedEndHour: allowedEndHour,
      allowedEndMinute: allowedEndMinute,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      locationRadius: locationRadius,
      locationMode: locationMode,
      openLimitCount: openLimitCount,
      openSessionSeconds: openSessionSeconds
    )
  }

  static func openPreset(
    name: String = "Open",
    count: Int? = 5,
    sessionSeconds: Double? = 600
  ) -> PresetValues {
    preset(
      name: name,
      blockKinds: [.open],
      openLimitCount: count,
      openSessionSeconds: sessionSeconds
    )
  }

  static func timerPreset(
    name: String = "Timer",
    seconds: Double = 1800
  ) -> PresetValues {
    preset(
      name: name,
      blockKinds: [.timer],
      timerLimitDurationSeconds: seconds
    )
  }

  static func allowedHourPreset(
    name: String = "AllowedHour",
    sh: Int = 9, sm: Int = 0, eh: Int = 17, em: Int = 0
  ) -> PresetValues {
    preset(
      name: name,
      blockKinds: [.allowedHour],
      allowedStartHour: sh,
      allowedStartMinute: sm,
      allowedEndHour: eh,
      allowedEndMinute: em
    )
  }

  static func locationPreset(
    name: String = "Location",
    lat: Double = 40.7128,
    lon: Double = -74.0060,
    radius: Double = 100,
    mode: String = "exit"
  ) -> PresetValues {
    preset(
      name: name,
      blockKinds: [.location],
      locationLatitude: lat,
      locationLongitude: lon,
      locationRadius: radius,
      locationMode: mode
    )
  }
}

class LimitTestCase: XCTestCase {
  func assertCommonPresetShape(
    _ preset: PresetValues,
    expected type: LimitType,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(preset.hasBlock(type), file: file, line: line)
    XCTAssertFalse(preset.name.isEmpty, file: file, line: line)
  }

  func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = y
    comps.month = m
    comps.day = d
    comps.hour = h
    comps.minute = min
    return Calendar.current.date(from: comps)!
  }
}
