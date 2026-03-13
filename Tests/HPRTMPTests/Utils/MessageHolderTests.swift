//
//  MessageHolderTests.swift
//  HPRTMPTests
//
//  Created by Huiping Guo on 2025/03/13.
//

import XCTest

@testable import HPRTMP

class MessageHolderTests: XCTestCase {
  func testRegisterAndRemoveMessage() async {
    // Given
    let holder = MessageHolder()
    let transactionId = 1

    // When
    await holder.register(transactionId: transactionId, message: TestMessage())
    let retrieved = await holder.removeMessage(transactionId: transactionId)

    // Then
    XCTAssertNotNil(retrieved)
  }

  func testRemoveNonExistentMessage() async {
    // Given
    let holder = MessageHolder()
    let transactionId = 999

    // When
    let retrieved = await holder.removeMessage(transactionId: transactionId)

    // Then
    XCTAssertNil(retrieved)
  }

  func testOverwriteMessage() async {
    // Given
    let holder = MessageHolder()
    let transactionId = 1

    // When
    await holder.register(transactionId: transactionId, message: TestMessage())
    await holder.register(transactionId: transactionId, message: TestMessage())
    let retrieved = await holder.removeMessage(transactionId: transactionId)

    // Then
    XCTAssertNotNil(retrieved)
  }

  func testMultipleMessages() async {
    // Given
    let holder = MessageHolder()

    // When
    await holder.register(transactionId: 1, message: TestMessage())
    await holder.register(transactionId: 2, message: TestMessage())

    let retrieved1 = await holder.removeMessage(transactionId: 1)
    let retrieved2 = await holder.removeMessage(transactionId: 2)

    // Then
    XCTAssertNotNil(retrieved1)
    XCTAssertNotNil(retrieved2)
  }

  func testRemoveAfterRegister() async {
    // Given
    let holder = MessageHolder()
    let transactionId = 5

    // When
    await holder.register(transactionId: transactionId, message: TestMessage())
    let firstRetrieve = await holder.removeMessage(transactionId: transactionId)
    let secondRetrieve = await holder.removeMessage(transactionId: transactionId)

    // Then
    XCTAssertNotNil(firstRetrieve)
    XCTAssertNil(secondRetrieve) // Message should be removed after first retrieval
  }
}

// MARK: - Test Message Type

struct TestMessage: RTMPMessage {
  let timestamp: Timestamp = Timestamp(0)
  var messageType: MessageType { .audio }
  var msgStreamId: MessageStreamId { .zero }
  var streamId: ChunkStreamId { ChunkStreamId(0) }
  var payload: Data { Data() }
  var priority: MessagePriority { .high }
}
