import XCTest
@testable import Rotblock

// MARK: - Collection[safe:]

final class CollectionSafeSubscriptTests: XCTestCase {

    func testInBoundsFirstElement() {
        let array = [10, 20, 30]
        XCTAssertEqual(array[safe: 0], 10)
    }

    func testInBoundsLastElement() {
        let array = [10, 20, 30]
        XCTAssertEqual(array[safe: 2], 30)
    }

    func testOutOfBoundsReturnsNil() {
        let array = [10, 20, 30]
        XCTAssertNil(array[safe: 3])
    }

    func testEmptyCollectionReturnsNil() {
        let array: [Int] = []
        XCTAssertNil(array[safe: 0])
    }

    func testNegativeIndexReturnsNil() {
        let array = [1, 2, 3]
        XCTAssertNil(array[safe: -1])
    }

    func testStringCollectionInBounds() {
        let words = ["alpha", "beta", "gamma"]
        XCTAssertEqual(words[safe: 1], "beta")
    }

    func testStringCollectionOutOfBounds() {
        let words = ["alpha", "beta", "gamma"]
        XCTAssertNil(words[safe: 5])
    }
}

// MARK: - FocusMessages

final class FocusMessagesTests: XCTestCase {

    func testMessagesArrayIsNonEmpty() {
        XCTAssertFalse(FocusMessages.messages.isEmpty)
    }

    func testAllMessagesHaveNonEmptyText() {
        for message in FocusMessages.messages {
            XCTAssertFalse(message.isEmpty, "Found empty message in FocusMessages.messages")
        }
    }

    func testGetRandomMessageIsFromCollection() {
        let message = FocusMessages.getRandomMessage()
        XCTAssertTrue(FocusMessages.messages.contains(message))
    }

    func testGetRandomMessageIsNonEmpty() {
        XCTAssertFalse(FocusMessages.getRandomMessage().isEmpty)
    }
}

