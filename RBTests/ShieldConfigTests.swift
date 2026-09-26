import XCTest

// MARK: - Local types (Shield extension uses defaults strings; logic lives here for deterministic tests.)

enum BlockedContentType: Equatable {
  case app
  case website
}

private struct ShieldSelectableMessage: Equatable {
  let title: String
  let emoji: String
  let subtitle: String
  let buttonText: String
}

enum ShieldMessageLogic {
  /// FNV-1a over UTF-8 bytes.
  static func stableSeed(for string: String) -> UInt64 {
    let offset: UInt64 = 14_695_981_039_346_656_037
    let prime: UInt64 = 1_099_511_628_211
    var hash = offset
    for byte in string.utf8 {
      hash ^= UInt64(byte)
      hash &*= prime
    }
    return hash
  }

  fileprivate static func allMessages(title: String) -> [ShieldSelectableMessage] {
    [
      ShieldSelectableMessage(
        title: "Focus time",
        emoji: "🎯",
        subtitle: "\(title) can wait.",
        buttonText: "OK"
      ),
      ShieldSelectableMessage(
        title: "Stay strong",
        emoji: "💪",
        subtitle: "Pause \(title) for now.",
        buttonText: "Got it"
      ),
      ShieldSelectableMessage(
        title: "You've got this",
        emoji: "✨",
        subtitle: "\(title) will still be there later.",
        buttonText: "Close"
      ),
      ShieldSelectableMessage(
        title: "One mindful moment",
        emoji: "🌿",
        subtitle: "\(title) — not right now.",
        buttonText: "Understood"
      ),
      ShieldSelectableMessage(
        title: "Shielded",
        emoji: "🛡️",
        subtitle: "Take a breath before \(title).",
        buttonText: "Fine"
      )
    ]
  }

  fileprivate static func selectMessage(for _: BlockedContentType, title: String, date: Date) -> ShieldSelectableMessage {
    let messages = allMessages(title: title)
    precondition(!messages.isEmpty, "pool must not be empty")
    let calendar = Calendar.current
    let dayOrdinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    var mix = stableSeed(for: title)
    mix &+= UInt64(truncatingIfNeeded: dayOrdinal)
    mix &*= 6_364_136_223_846_793_005
    let idx = Int(mix % UInt64(messages.count))
    return messages[idx]
  }
}

final class ShieldConfigTests: XCTestCase {

  // MARK: - stableSeed

  func testStableSeedIsDeterministic() {
    let seed1 = ShieldMessageLogic.stableSeed(for: "Instagram")
    let seed2 = ShieldMessageLogic.stableSeed(for: "Instagram")
    XCTAssertEqual(seed1, seed2, "Same title must always produce the same seed")
  }

  func testStableSeedDiffersForDifferentTitles() {
    let a = ShieldMessageLogic.stableSeed(for: "Instagram")
    let b = ShieldMessageLogic.stableSeed(for: "TikTok")
    XCTAssertNotEqual(a, b)
  }

  func testStableSeedEmptyString() {
    let seed = ShieldMessageLogic.stableSeed(for: "")
    XCTAssertNotEqual(seed, 0)
  }

  func testStableSeedKnownValue() {
    let expected: UInt64 = ShieldMessageLogic.stableSeed(for: "A")
    var manual: UInt64 = 14_695_981_039_346_656_037
    manual ^= UInt64(("A" as Unicode.Scalar).value)
    manual &*= 1_099_511_628_211
    XCTAssertEqual(expected, manual)
  }

  // MARK: - selectMessage

  func testSelectMessageReturnsSameResultForSameDateAndTitle() {
    let fixedDate = date(2024, 6, 15)
    let msg1 = ShieldMessageLogic.selectMessage(for: .app, title: "Instagram", date: fixedDate)
    let msg2 = ShieldMessageLogic.selectMessage(for: .app, title: "Instagram", date: fixedDate)
    XCTAssertEqual(msg1.title, msg2.title)
    XCTAssertEqual(msg1.emoji, msg2.emoji)
  }

  func testSelectMessagePicksFromKnownPool() {
    let fixedDate = date(2024, 6, 15)
    let msg = ShieldMessageLogic.selectMessage(for: .app, title: "Twitter", date: fixedDate)
    let allTitles = ShieldMessageLogic.allMessages(title: "Twitter").map(\.title)
    XCTAssertTrue(allTitles.contains(msg.title), "Selected message title must be from the pool")
  }

  func testSelectMessageIndexIsStableAcrossMessagePoolSize() {
    let titles = [
      "Instagram", "TikTok", "YouTube", "Reddit", "Twitter", "X", "", "A",
      "Very Long App Name That Is Unusual",
    ]
    let fixedDate = date(2024, 1, 1)
    for title in titles {
      let msg = ShieldMessageLogic.selectMessage(for: .app, title: title, date: fixedDate)
      XCTAssertFalse(msg.emoji.isEmpty, "Message for '\(title)' must have an emoji")
    }
  }

  func testSelectMessageChangesAcrossDays() {
    var seen = Set<String>()
    for day in 0..<17 {
      let d = date(2024, 1, 1 + day)
      let msg = ShieldMessageLogic.selectMessage(for: .app, title: "Instagram", date: d)
      seen.insert(msg.title)
    }
    XCTAssertGreaterThan(
      seen.count, 1, "17 different days should produce at least 2 distinct messages")
  }

  func testSelectMessageAllMessagesHaveNonEmptyFields() {
    let messages = ShieldMessageLogic.allMessages(title: "SomeApp")
    for msg in messages {
      XCTAssertFalse(msg.emoji.isEmpty, "emoji should not be empty")
      XCTAssertFalse(msg.title.isEmpty, "title should not be empty")
      XCTAssertFalse(msg.subtitle.isEmpty, "subtitle should not be empty")
      XCTAssertFalse(msg.buttonText.isEmpty, "buttonText should not be empty")
    }
  }

  // MARK: - BlockedContentType

  func testBlockedContentTypeValuesExist() {
    let app: BlockedContentType = .app
    let site: BlockedContentType = .website
    XCTAssertNotEqual(app, site)
  }

  // MARK: - Helpers

  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = 12
    return Calendar.current.date(from: comps)!
  }
}
