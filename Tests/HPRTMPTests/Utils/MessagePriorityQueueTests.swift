import XCTest
@testable import HPRTMP

final class MessagePriorityQueueTests: XCTestCase {

  // MARK: - Basic Enqueue/Dequeue Tests

  func testEnqueueAndDequeue() async {
    let queue = MessagePriorityQueue()
    let message = createMessage(priority: .medium)

    await queue.enqueue(message, firstType: false)

    let container = await queue.dequeue()
    XCTAssertNotNil(container)
    XCTAssertEqual(container?.message.priority, .medium)
    XCTAssertEqual(container?.isFirstType, false)
  }

  func testEmptyQueueCheck() async {
    let queue = MessagePriorityQueue()

    let isEmpty = await queue.isEmpty
    XCTAssertTrue(isEmpty)

    await queue.enqueue(createMessage(priority: .low), firstType: false)

    let isEmptyAfterEnqueue = await queue.isEmpty
    XCTAssertFalse(isEmptyAfterEnqueue)
  }

  func testPendingMessageCount() async {
    let queue = MessagePriorityQueue()

    var count = await queue.pendingMessageCount
    XCTAssertEqual(count, 0)

    await queue.enqueue(createMessage(priority: .high), firstType: false)
    await queue.enqueue(createMessage(priority: .medium), firstType: false)
    await queue.enqueue(createMessage(priority: .low), firstType: false)

    count = await queue.pendingMessageCount
    XCTAssertEqual(count, 3)

    _ = await queue.dequeue()
    count = await queue.pendingMessageCount
    XCTAssertEqual(count, 2)
  }

  // MARK: - Priority Order Tests

  func testPriorityOrder() async {
    let queue = MessagePriorityQueue()

    // Enqueue in random order
    await queue.enqueue(createMessage(priority: .low), firstType: false)
    await queue.enqueue(createMessage(priority: .high), firstType: false)
    await queue.enqueue(createMessage(priority: .medium), firstType: false)

    // Should dequeue in priority order: high, medium, low
    let first = await queue.dequeue()
    XCTAssertEqual(first?.message.priority, .high)

    let second = await queue.dequeue()
    XCTAssertEqual(second?.message.priority, .medium)

    let third = await queue.dequeue()
    XCTAssertEqual(third?.message.priority, .low)
  }

  func testSamePriorityFIFOOrder() async {
    let queue = MessagePriorityQueue()

    let message1 = createMessage(priority: .medium, timestamp: 100)
    let message2 = createMessage(priority: .medium, timestamp: 200)
    let message3 = createMessage(priority: .medium, timestamp: 300)

    await queue.enqueue(message1, firstType: false)
    await queue.enqueue(message2, firstType: false)
    await queue.enqueue(message3, firstType: false)

    // Should maintain FIFO order for same priority
    let first = await queue.dequeue()
    XCTAssertEqual(first?.message.timestamp, 100)

    let second = await queue.dequeue()
    XCTAssertEqual(second?.message.timestamp, 200)

    let third = await queue.dequeue()
    XCTAssertEqual(third?.message.timestamp, 300)
  }

  // MARK: - Wait/Resume Tests

  func testDequeueWaitsWhenEmpty() async {
    let queue = MessagePriorityQueue()

    let expectation = expectation(description: "Dequeue waits for message")
    expectation.isInverted = true // Should NOT fulfill immediately

    Task {
      _ = await queue.dequeue()
      expectation.fulfill()
    }

    // Wait 100ms - dequeue should still be waiting
    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func testEnqueueResumesWaitingDequeue() async {
    let queue = MessagePriorityQueue()

    let expectation = expectation(description: "Dequeue resumes after enqueue")

    let dequeueTask = Task { () -> RTMPMessage? in
      let container = await queue.dequeue()
      expectation.fulfill()
      return container?.message
    }

    // Give the dequeue task time to start waiting
    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

    // Now enqueue a message
    let message = createMessage(priority: .high)
    await queue.enqueue(message, firstType: false)

    await fulfillment(of: [expectation], timeout: 1.0)

    let dequeuedMessage = await dequeueTask.value
    XCTAssertNotNil(dequeuedMessage)
    XCTAssertEqual(dequeuedMessage?.priority, .high)
  }

  // MARK: - Task Cancellation Tests

  func testTaskCancellationResumesDequeue() async {
    let queue = MessagePriorityQueue()

    let expectation = expectation(description: "Dequeue returns nil after cancellation")

    let task = Task {
      let container = await queue.dequeue()
      XCTAssertNil(container, "Dequeue should return nil when task is cancelled")
      expectation.fulfill()
    }

    // Give the task time to start waiting
    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

    // Cancel the task
    task.cancel()

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func testRepeatedCancellationHandling() async {
    // Test that queue can handle multiple cancel-resume cycles
    let queue = MessagePriorityQueue()

    for _ in 0..<3 {
      let task = Task {
        _ = await queue.dequeue()
      }

      try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
      task.cancel()

      // Give time for cancellation to process
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    // After all cancellations, queue should still work
    await queue.enqueue(createMessage(priority: .high), firstType: false)
    let container = await queue.dequeue()
    XCTAssertNotNil(container)
  }

  // MARK: - Concurrent Tests

  func testConcurrentEnqueueDequeue() async {
    let queue = MessagePriorityQueue()
    let messageCount = 100

    // Prepare messages outside the task group
    let messages: [RTMPMessage] = (0..<messageCount).map { i in
      let priority: MessagePriority = i % 3 == 0 ? .high : i % 3 == 1 ? .medium : .low
      return createMessage(priority: priority)
    }

    // Spawn multiple tasks to enqueue messages concurrently
    await withTaskGroup(of: Void.self) { group in
      for message in messages {
        group.addTask {
          await queue.enqueue(message, firstType: false)
        }
      }
    }

    // Verify all messages can be dequeued
    var dequeuedCount = 0
    while dequeuedCount < messageCount {
      if let _ = await queue.dequeue() {
        dequeuedCount += 1
      }
    }

    XCTAssertEqual(dequeuedCount, messageCount)

    let isEmpty = await queue.isEmpty
    XCTAssertTrue(isEmpty)
  }

  func testSingleConsumerSequentialDequeue() async {
    // MessagePriorityQueue is designed for single-consumer pattern
    let queue = MessagePriorityQueue()
    let messageCount = 50

    // Enqueue messages
    for _ in 0..<messageCount {
      await queue.enqueue(createMessage(priority: .medium), firstType: false)
    }

    // Single consumer dequeues all messages
    var dequeuedCount = 0
    while dequeuedCount < messageCount {
      if let _ = await queue.dequeue() {
        dequeuedCount += 1
      }
    }

    XCTAssertEqual(dequeuedCount, messageCount)
    let isEmpty = await queue.isEmpty
    XCTAssertTrue(isEmpty)
  }

  // MARK: - Helper Methods

  private func createMessage(priority: MessagePriority, timestamp: UInt32 = 0) -> RTMPMessage {
    // Create a test message with specified priority
    switch priority {
    case .high:
      return TestHighPriorityMessage(timestamp: timestamp)
    case .medium:
      return TestMediumPriorityMessage(timestamp: timestamp)
    case .low:
      return TestLowPriorityMessage(timestamp: timestamp)
    }
  }
}

// MARK: - Test Message Types

struct TestHighPriorityMessage: RTMPMessage {
  let timestamp: UInt32
  var messageType: MessageType { .chunkSize }
  var msgStreamId: Int { 0 }
  var streamId: UInt16 { 3 }
  var payload: Data { Data() }
  var priority: MessagePriority { .high }
}

struct TestMediumPriorityMessage: RTMPMessage {
  let timestamp: UInt32
  var messageType: MessageType { .audio }
  var msgStreamId: Int { 0 }
  var streamId: UInt16 { 4 }
  var payload: Data { Data() }
  var priority: MessagePriority { .medium }
}

struct TestLowPriorityMessage: RTMPMessage {
  let timestamp: UInt32
  var messageType: MessageType { .video }
  var msgStreamId: Int { 0 }
  var streamId: UInt16 { 5 }
  var payload: Data { Data() }
  var priority: MessagePriority { .low }
}

