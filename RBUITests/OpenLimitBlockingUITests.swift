// OpenLimitBlockingUITests.swift
// RBUITests — UI test target (physical device only).
//
// Prerequisites:
// 1. Physical device only. Screen Time block enforcement does not fire on
//    the simulator.
// 2. Create one preset named exactly "RB_OPEN_BLOCK_TEST" in Rotblock:
//      • Limit type  : Open Limit
//      • Opens / day : leave blank  (blank = always blocked once active)
//      • Min / open  : leave blank
//      • Select Safari as a blocked app and save.
//    Do this once; the tests activate and deactivate it automatically.
// 3. The preset must be *inactive* at test start.
//
// Why a blank open limit:
// When openLimitCount and openSessionSeconds are both nil, PresetActivationService
// calls `deviceActivity.applyRestrictions(...)` immediately, so the block fires on
// the very first launch attempt. That lets the tests assert the shield
// deterministically without burning through a daily counter.

import XCTest

final class OpenLimitBlockingUITests: XCTestCase {

  // MARK: - Constants

  private enum TestPreset {
    static let name = "RB_OPEN_BLOCK_TEST"
  }

  private enum BlockedApp {
    static let name = "Safari"
  }

  private enum ShieldDefaults {
    static let subtitle = "Shield Activated"
    static let primaryButton = "Temporary access"
    static let secondaryButton = "Accept redirection"
  }

  // MARK: - Apps

  private let rotblock = XCUIApplication()
  // The Screen Time overlay renders in SpringBoard, not inside the blocked
  // app's process.  Querying `rotblock` or the Safari app instance will find
  // nothing — all shield assertions must go through springboard.
  private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

  // MARK: - Setup / Teardown

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    // Do NOT pass -UITEST_MODE here. Screen Time enforcement requires
    // FamilyControls authorization to be in scope; UITEST_MODE bypasses the
    // auth check, so applyRestrictions() becomes a silent no-op and the shield
    // never fires. The normal launch path establishes auth before we reach
    // PresetsView — navigateToPresetsTab() waits long enough for it.
    rotblock.launch()
    activateTestPreset()
  }

  override func tearDown() {
    deactivateTestPreset()
    XCUIDevice.shared.press(.home)
    super.tearDown()
  }

  // MARK: - Tests

  /// Verifies that opening a blocked app with an active Open-Limit preset
  /// surfaces the Rotblock shield in SpringBoard.
  func testOpenLimitBlock_presentsShield() {
    openBlockedAppViaSpotlight()
    assertShieldSubtitleVisible()
  }

  /// Verifies the shield's primary action button (Temporary access) is shown.
  func testOpenLimitBlock_primaryActionButton_isVisible() {
    openBlockedAppViaSpotlight()
    let btn = springboard.buttons[ShieldDefaults.primaryButton]
    XCTAssertTrue(
      btn.waitForExistence(timeout: 10),
      "Shield primary button '\(ShieldDefaults.primaryButton)' not found — "
        + "block may not have fired or shield copy was changed in Settings → Messages"
    )
  }

  /// Verifies the shield's secondary action button (Accept redirection) is shown.
  func testOpenLimitBlock_secondaryActionButton_isVisible() {
    openBlockedAppViaSpotlight()
    let btn = springboard.buttons[ShieldDefaults.secondaryButton]
    XCTAssertTrue(
      btn.waitForExistence(timeout: 10),
      "Shield secondary button '\(ShieldDefaults.secondaryButton)' not found"
    )
  }

  /// Verifies both action buttons are present simultaneously, confirming the
  /// full shield layout rendered correctly.
  func testOpenLimitBlock_bothShieldActions_arePresentTogether() {
    openBlockedAppViaSpotlight()
    let primary = springboard.buttons[ShieldDefaults.primaryButton]
    let secondary = springboard.buttons[ShieldDefaults.secondaryButton]
    XCTAssertTrue(primary.waitForExistence(timeout: 10), "Primary shield button not found")
    // Secondary button renders with primary — give it a short independent wait
    // rather than a synchronous .exists check that can race.
    XCTAssertTrue(secondary.waitForExistence(timeout: 3), "Secondary shield button not found alongside primary")
  }

  // MARK: - Preset control

  private func activateTestPreset() {
    navigateToPresetsTab()

    let nameLabel = rotblock.staticTexts["preset.name.\(TestPreset.name)"]
    XCTAssertTrue(
      nameLabel.waitForExistence(timeout: 5),
      "Preset '\(TestPreset.name)' not found — create it in Rotblock first (see file header)"
    )

    // Tap the card to expand it.
    nameLabel.tap()

    let startPredicate = NSPredicate(format: "identifier BEGINSWITH 'preset.action.start.'")
    let startButton = rotblock.buttons.matching(startPredicate).firstMatch
    XCTAssertTrue(
      startButton.waitForExistence(timeout: 3),
      "Start button not found after expanding card"
    )
    startButton.tap()

    // Allow Screen Time to register the new restriction.
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
    // Allow up to 8 s for splash + auth check to complete before the tab bar appears.
    let presetsTab = rotblock.buttons["tab.presets"]
    if presetsTab.waitForExistence(timeout: 8) {
      presetsTab.tap()
    }
  }

  // MARK: - SpringBoard navigation

  private func openBlockedAppViaSpotlight() {
    XCUIDevice.shared.press(.home)
    _ = springboard.wait(for: .runningForeground, timeout: 3)

    let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
    let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
    start.press(forDuration: 0.05, thenDragTo: end)

    let searchField = springboard.searchFields.firstMatch
    XCTAssertTrue(searchField.waitForExistence(timeout: 4), "Spotlight search field not found")
    searchField.tap()
    searchField.typeText(BlockedApp.name)

    let icon = springboard.icons[BlockedApp.name].firstMatch
    XCTAssertTrue(
      icon.waitForExistence(timeout: 4),
      "\(BlockedApp.name) icon not found in Spotlight results"
    )
    icon.tap()
    // No sleep needed — waitForExistence in each assertion polls until the
    // shield appears or the timeout expires.
  }

  // MARK: - Shield assertions

  private func assertShieldSubtitleVisible() {
    let subtitle = springboard.staticTexts[ShieldDefaults.subtitle]
    XCTAssertTrue(
      subtitle.waitForExistence(timeout: 10),
      """
      Shield subtitle '\(ShieldDefaults.subtitle)' not visible in SpringBoard.
      Possible causes:
        • Block has not fired — increase the sleep in openBlockedAppViaSpotlight()
        • Preset is not the always-blocked variant (openLimitCount/openSessionSeconds both nil)
        • Shield subtitle was customised in Rotblock → Settings → Messages
        • Screen Time entitlement not active on this build
      """
    )
  }
}
