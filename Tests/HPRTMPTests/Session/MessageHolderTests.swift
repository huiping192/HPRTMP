import XCTest
@testable import HPRTMP

final class MessageHolderTests: XCTestCase {

  // MARK: - Basic Register/Remove Tests

  func testRegisterAndRemoveMessage() async {
    let holder = MessageHolder()
    let message = TestMediumPriorityMessage(timestamp: Timestamp(100))
    let transactionId = 1

    await holder.register(transactionId: transactionId, message: message)

    let retrievedMessage = await holder.removeMessage(transactionId: transactionId)
    XCTAssertNotNil(retrievedMessage)
    XCTAssertTrue(retrievedMessage is TestMediumPriorityMessage)
  }

  func testRemoveNonExistentMessage() async {
    let holder = MessageHolder()

    let retrievedMessage = await holder.removeMessage(transactionId: 999)
    XCTAssertNil(retrievedMessage)
  }

  func testRemoveMessageAlsoDeletes() async {
    let holder = MessageHolder()
    let message = TestMediumPriorityMessage(timestamp: Timestamp(100))
    let transactionId = 1

    await holder.register(transactionId: transactionId, message: message)

    // First removal should succeed
    let firstRemoval = await holder.removeMessage(transactionId: transactionId)
    XCTAssertNotNil(firstRemoval)

    // Second removal should return nil (already removed)
    let secondRemoval = await holder.removeMessage(transactionId: transactionId)
    XCTAssertNil(secondRemoval)
  }

  // MARK: - Contains Tests

  func testContainsReturnsTrueForRegisteredMessage() async {
    let holder = MessageHolder()
    let message = TestMediumPriorityMessage(timestamp: Timestamp(100))
    let transactionId = 1

    await holder.register(transactionId: transactionId, message: message)

    let contains = await holder.contains(transactionId: transactionId)
    XCTAssertTrue(contains)
  }

  func testContainsReturnsFalseForNonExistentTransaction() async {
    let holder = MessageHolder()

    let contains = await holder.contains(transactionId: 999)
    XCTAssertFalse(contains)
  }

  func testContainsReturnsFalseAfterMessageRemoval() async {
    let holder = MessageHolder()
    let message = TestMediumPriorityMessage(timestamp: Timestamp(100))
    let transactionId = 1

    await holder.register(transactionId: transactionId, message: message)
    _ = await holder.removeMessage(transactionId: transactionId)

    let contains = await holder.contains(transactionId: transactionId)
    XCTAssertFalse(contains)
  }

  // MARK: - Count Tests

  func testCountStartsAtZero() async {
    let holder = MessageHolder()

    let count = await holder.count
    XCTAssertEqual(count, 0)
  }

  func testCountIncreasesWithRegistration() async {
    let holder = MessageHolder()

    await holder.register(transactionId: 1, message: TestMediumPriorityMessage(timestamp: Timestamp(100)))
    await holder.register(transactionId: 2, message: TestMediumPriorityMessage(timestamp: Timestamp(200)))

    let count = await holder.count
    XCTAssertEqual(count, 2)
  }

  func testCountDecreasesAfterRemoval() async {
    let holder = MessageHolder()

    await holder.register(transactionId: 1, message: TestMediumPriorityMessage(timestamp: Timestamp(100)))
    await holder.register(transactionId: 2, message: TestMediumPriorityMessage(timestamp: Timestamp(200)))

    _ = await holder.removeMessage(transactionId: 1)

    let count = await holder.count
    XCTAssertEqual(count, 1)
  }

  // MARK: - ClearAll Tests

  func testClearAllRemovesAllMessages() async {
    let holder = MessageHolder()

    await holder.register(transactionId: 1, message: TestMediumPriorityMessage(timestamp: Timestamp(100)))
    await holder.register(transactionId: 2, message: TestMediumPriorityMessage(timestamp: Timestamp(200)))
    await holder.register(transactionId: 3, message: TestMediumPriorityMessage(timestamp: Timestamp(300)))

    var count = await holder.count
    XCTAssertEqual(count, 3)

    await holder.clearAll()

    count = await holder.count
    XCTAssertEqual(count, 0)
  }

  func testClearAllOnEmptyHolder() async {
    let holder = MessageHolder()

    await holder.clearAll()

    let count = await holder.count
    XCTAssertEqual(count, 0)
  }

  // MARK: - Multiple Transaction IDs

  func testMultipleTransactionIds() async {
    let holder = MessageHolder()

    await holder.register(transactionId: 1, message: TestHighPriorityMessage(timestamp: Timestamp(100)))
    await holder.register(transactionId: 2, message: TestMediumPriorityMessage(timestamp: Timestamp(200)))
    await holder.register(transactionId: 3, message: TestLowPriorityMessage(timestamp: Timestamp(300)))

    let msg1 = await holder.removeMessage(transactionId: 1)
    let msg2 = await holder.removeMessage(transactionId: 2)
    let msg3 = await holder.removeMessage(transactionId: 3)

    XCTAssertNotNil(msg1)
    XCTAssertNotNil(msg2)
    XCTAssertNotNil(msg3)

    XCTAssertTrue(msg1 is TestHighPriorityMessage)
    XCTAssertTrue(msg2 is TestMediumPriorityMessage)
    XCTAssertTrue(msg3 is TestLowPriorityMessage)
  }

  func testOverwriteExistingTransactionId() async {
    let holder = MessageHolder()
    let transactionId = 1

    await holder.register(transactionId: transactionId, message: TestHighPriorityMessage(timestamp: Timestamp(100)))
    await holder.register(transactionId: transactionId, message: TestMediumPriorityMessage(timestamp: Timestamp(200)))

    let count = await holder.count
    XCTAssertEqual(count, 1, "Should still be 1 since we overwrote")

    let retrievedMessage = await holder.removeMessage(transactionId: transactionId)
    XCTAssertNotNil(retrievedMessage)
    XCTAssertTrue(retrievedMessage is TestMediumPriorityMessage, "Should be the second message")
  }
}
