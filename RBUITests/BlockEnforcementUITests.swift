// BlockEnforcementUITests.swift
// RBTests — must belong to a UI Test target (not the hosted unit test target).
//
// Prerequisites:
// 1. Physical device only. Screen Time APIs and block enforcement do not fire
//    on the simulator.
// 2. Create one preset named exactly "RB_BLOCK_TEST" in Rotblock, with Safari
//    selected as a blocked app, and save it. Do this once; the test activates
//    and deactivates it automatically.
// 3. The preset must be *inactive* (not running) at test start.
//
// How it works:
// setUp       → launches Rotblock, navigates to Presets, starts the test preset
// test bodies → press Home, open Safari via Spotlight, assert shield text visible
// tearDown    → returns to Rotblock, stops the test preset, presses Home

import XCTest

final class BlockEnforcementUITests: XCTestCase {

  // MARK: - Constants

  private enum TestPreset {
    static let name = "RB_BLOCK_TEST"
  }

  private enum BlockedApp {
    static let name = "Safari"
    static let bundleID = "com.apple.mobilesafari"
  }

  /// Matches AppCustomizationView defaults. Update if the user has saved
  /// custom copy in the Messages settings screen.
  private enum ShieldDefaults {
    static let subtitle = "Shield Activated"
    static let primaryButton = "Temporary access"
    static let secondaryButton = "Accept redirection"
  }

  // MARK: - Apps

  private let rotblock = XCUIApplication()
  private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

  // MARK: - Setup / Teardown

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    rotblock.launch()
    activateTestPreset()
  }

  override func tearDown() {
    deactivateTestPreset()
    XCUIDevice.shared.press(.home)
    super.tearDown()
  }

  // MARK: - Tests

  /// Verifies that opening a blocked app shows the Rotblock shield.
  func testBlockedApp_presentsShield() {
    openBlockedAppViaSpotlight()
    assertShieldIsVisible()
  }

  /// Verifies that the shield's primary action button is present.
  func testShield_primaryActionButton_isVisible() {
    openBlockedAppViaSpotlight()
    let btn = springboard.buttons[ShieldDefaults.primaryButton]
    XCTAssertTrue(
      btn.waitForExistence(timeout: 6),
      "Shield primary button '\(ShieldDefaults.primaryButton)' not found — block may not have fired"
    )
  }

  /// Verifies that the shield's secondary action button is present.
  func testShield_secondaryActionButton_isVisible() {
    openBlockedAppViaSpotlight()
    let btn = springboard.buttons[ShieldDefaults.secondaryButton]
    XCTAssertTrue(
      btn.waitForExistence(timeout: 6),
      "Shield secondary button '\(ShieldDefaults.secondaryButton)' not found"
    )
  }
  private func findPresetLabel(_ name: String) -> XCUIElement {
    let label = rotblock.staticTexts["preset.name.\(name)"]
    for _ in 0..<6 where !label.exists {
      rotblock.swipeUp()
    }
    return label
  }
  // MARK: - Preset control

  private func activateTestPreset() {
    navigateToPresetsTab()

    let nameLabel = findPresetLabel(TestPreset.name)
    XCTAssertTrue(
      nameLabel.waitForExistence(timeout: 8),
      "Preset '\(TestPreset.name)' not found — create it in Rotblock first (see file header)"
    )
    nameLabel.tap()

    // Tap the start button. Identifier format: "preset.action.start.<uuid>".
    let startPredicate = NSPredicate(format: "identifier BEGINSWITH 'preset.action.start.'")
    let startButton = rotblock.buttons.matching(startPredicate).firstMatch
    XCTAssertTrue(
      startButton.waitForExistence(timeout: 3), "Start button not found after expanding card")
    startButton.tap()

    // Brief pause for Screen Time to register the new monitor.
    Thread.sleep(forTimeInterval: 1.5)
  }

  private func deactivateTestPreset() {
    guard rotblock.state == .runningForeground || bringRotblockToFront() else { return }
    navigateToPresetsTab()

    let stopPredicate = NSPredicate(format: "identifier BEGINSWITH 'preset.action.stop.'")
    let stopButton = rotblock.buttons.matching(stopPredicate).firstMatch
    if stopButton.waitForExistence(timeout: 3) {
      stopButton.tap()
    }
  }

  @discardableResult
  private func bringRotblockToFront() -> Bool {
    rotblock.activate()
    return rotblock.wait(for: .runningForeground, timeout: 5)
  }

  private func navigateToPresetsTab() {
    bringRotblockToFront()
    let presetsTab = rotblock.tabBars.buttons["Presets"]
    XCTAssertTrue(presetsTab.waitForExistence(timeout: 6), "Presets tab not found")
    presetsTab.tap()

    let screen = rotblock.otherElements["presets.screen"]
    XCTAssertTrue(screen.waitForExistence(timeout: 6), "Presets screen did not appear")
  }
  // MARK: - SpringBoard navigation

  /// Opens the blocked app using Spotlight so the test does not rely on
  /// knowing which home screen page the app icon lives on.
  private func openBlockedAppViaSpotlight() {
    XCUIDevice.shared.press(.home)
    _ = springboard.wait(for: .runningForeground, timeout: 3)

    // Swipe down from the middle of the screen to reveal Spotlight.
    let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
    let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
    start.press(forDuration: 0.05, thenDragTo: end)

    let searchField = springboard.searchFields.firstMatch
    XCTAssertTrue(searchField.waitForExistence(timeout: 4), "Spotlight search field not found")
    searchField.tap()
    searchField.typeText(BlockedApp.name)

    // The app icon appears in the "Top Hit" or icon results row.
    let icon = springboard.icons[BlockedApp.name].firstMatch
    XCTAssertTrue(
      icon.waitForExistence(timeout: 4), "\(BlockedApp.name) icon not found in Spotlight results")
    icon.tap()

    // Give the OS time to process the launch and fire the block.
    Thread.sleep(forTimeInterval: 1.0)
  }

  // MARK: - Shield assertions

  /// The shield UI is rendered by the RBShieldConfig extension and appears
  /// in the SpringBoard process, not in the blocked app's process.
  private func assertShieldIsVisible() {
    let subtitle = springboard.staticTexts[ShieldDefaults.subtitle]
    XCTAssertTrue(
      subtitle.waitForExistence(timeout: 6),
      """
      Shield subtitle '\(ShieldDefaults.subtitle)' not visible in SpringBoard.
      Possible causes:
        • Block has not fired yet — increase the sleep above
        • Shield subtitle was customised in Rotblock → Settings → Messages
        • Screen Time entitlement not active on this build
      """
    )
  }
}
