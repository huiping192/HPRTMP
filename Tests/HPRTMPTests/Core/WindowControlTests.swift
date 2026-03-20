
import XCTest
@testable import HPRTMP

final class WindowControlTests: XCTestCase {

  func testAddInBytesCount() async {
    actor Counter {
      var value: UInt32 = 0
      func update(_ newValue: UInt32) { value = newValue }
    }
    let counter = Counter()
    let windowControl = WindowControl()

    await windowControl.setWindowSize(250000)
    await windowControl.setInBytesWindowEvent { totalInBytes in
      await counter.update(totalInBytes)
    }

    await windowControl.addInBytesCount(250000)

    let count = await windowControl.totalInBytesCount
    let seq = await windowControl.totalInBytesSeq
    let inbytesCount = await counter.value
    XCTAssertEqual(count, 250000 as UInt64)
    XCTAssertEqual(seq, 2 as UInt64)
    XCTAssertEqual(inbytesCount, 250000 as UInt32)


    await windowControl.addInBytesCount(250000)
    let count2 = await windowControl.totalInBytesCount
    let seq2 = await windowControl.totalInBytesSeq
    let inbytesCount2 = await counter.value
    XCTAssertEqual(count2, 500000 as UInt64)
    XCTAssertEqual(seq2, 3 as UInt64)
    XCTAssertEqual(inbytesCount2, 500000 as UInt32)
  }

  func testAddOutBytesCount() async {
    let windowControl = WindowControl()
    await windowControl.setWindowSize(250000)

    await windowControl.addOutBytesCount(250000)

    let count = await windowControl.totalOutBytesCount
    let seq = await windowControl.totalOutBytesSeq
    XCTAssertEqual(count, 250000 as UInt64)
    XCTAssertEqual(seq, 2 as UInt64)


    await windowControl.addOutBytesCount(250000)
    let count2 = await windowControl.totalOutBytesCount
    let seq2 = await windowControl.totalOutBytesSeq
    XCTAssertEqual(count2, 500000 as UInt64)
    XCTAssertEqual(seq2, 3 as UInt64)
  }

  func testShouldWaitAcknowledgement() async {
    let windowControl = WindowControl()

    await windowControl.setWindowSize(240000)

    for _ in 0..<5 {
      await windowControl.addOutBytesCount(50000)
    }
    var shouldWaitAcknowledgement = await windowControl.shouldWaitAcknowledgement
    XCTAssertTrue(shouldWaitAcknowledgement)

    await windowControl.updateReceivedAcknowledgement(250000)
    shouldWaitAcknowledgement = await windowControl.shouldWaitAcknowledgement
    XCTAssertFalse(shouldWaitAcknowledgement)
  }

  // MARK: - ACK Timeout Tests

  func testAckTimeoutDisablesFlowControl() async throws {
    let windowControl = WindowControl(ackTimeout: 0.1)
    await windowControl.setWindowSize(240000)

    for _ in 0..<5 {
      await windowControl.addOutBytesCount(50000)
    }

    // Initially should wait (window exceeded)
    let shouldWaitBefore = await windowControl.shouldWaitAcknowledgement
    XCTAssertTrue(shouldWaitBefore)

    // Wait past the timeout
    try await Task.sleep(nanoseconds: 200_000_000)

    // After timeout, flow control should be disabled
    let shouldWaitAfter = await windowControl.shouldWaitAcknowledgement
    XCTAssertFalse(shouldWaitAfter)

    let ackDisabled = await windowControl.ackDisabled
    XCTAssertTrue(ackDisabled)
  }

  func testAckRecoveryReenablesFlowControl() async throws {
    let windowControl = WindowControl(ackTimeout: 0.1)
    await windowControl.setWindowSize(240000)

    for _ in 0..<5 {
      await windowControl.addOutBytesCount(50000)
    }

    // Trigger timeout
    _ = await windowControl.shouldWaitAcknowledgement
    try await Task.sleep(nanoseconds: 200_000_000)
    _ = await windowControl.shouldWaitAcknowledgement  // actually disables

    let ackDisabledBefore = await windowControl.ackDisabled
    XCTAssertTrue(ackDisabledBefore)

    // Server sends an ACK — flow control should be re-enabled
    await windowControl.updateReceivedAcknowledgement(250000)

    let ackDisabledAfter = await windowControl.ackDisabled
    XCTAssertFalse(ackDisabledAfter)
  }

  func testUInt64NoOverflow() async {
    let windowControl = WindowControl()
    await windowControl.setWindowSize(2500000)

    // Add more than UInt32.max bytes total
    await windowControl.addOutBytesCount(UInt32.max)
    await windowControl.addOutBytesCount(1)

    let count = await windowControl.totalOutBytesCount
    let expected: UInt64 = UInt64(UInt32.max) + 1
    XCTAssertEqual(count, expected)
    XCTAssertGreaterThan(count, UInt64(UInt32.max))
  }

  // MARK: - ACK Mode Tests

  func testYouTubeIncrementalMode() async {
    let windowControl = WindowControl()

    // YouTube sends same value (131325) every time
    await windowControl.updateReceivedAcknowledgement(131325)
    var received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 131325)

    await windowControl.updateReceivedAcknowledgement(131325)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 262650) // 131325 * 2

    await windowControl.updateReceivedAcknowledgement(131325)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 393975) // 131325 * 3

    await windowControl.updateReceivedAcknowledgement(131325)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 525300) // 131325 * 4
  }

  func testSRSCumulativeMode() async {
    let windowControl = WindowControl()

    // SRS/NDS sends cumulative byte count
    await windowControl.updateReceivedAcknowledgement(100000)
    var received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 100000)

    await windowControl.updateReceivedAcknowledgement(250000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 250000)

    await windowControl.updateReceivedAcknowledgement(400000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 400000)

    await windowControl.updateReceivedAcknowledgement(600000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 600000)
  }

  func testYouTubeIncrementValueChange() async {
    let windowControl = WindowControl()

    // YouTube mode detected
    await windowControl.updateReceivedAcknowledgement(100000)
    await windowControl.updateReceivedAcknowledgement(100000)
    var received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 200000)

    // Increment value changes (should still work)
    await windowControl.updateReceivedAcknowledgement(150000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 350000) // 200000 + 150000

    await windowControl.updateReceivedAcknowledgement(150000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 500000) // 350000 + 150000
  }

  func testCumulativeModeACKDecrease() async {
    let windowControl = WindowControl()

    // SRS mode detected
    await windowControl.updateReceivedAcknowledgement(100000)
    await windowControl.updateReceivedAcknowledgement(250000)
    var received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 250000)

    // ACK decreased, should be ignored
    await windowControl.updateReceivedAcknowledgement(200000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 250000) // Should remain unchanged

    // Normal ACK continues
    await windowControl.updateReceivedAcknowledgement(300000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 300000)
  }

  func testModeDetectionWithInitialDecrease() async {
    let windowControl = WindowControl()

    // First ACK
    await windowControl.updateReceivedAcknowledgement(100000)
    var received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 100000)

    // Second ACK decreased (should default to cumulative mode)
    await windowControl.updateReceivedAcknowledgement(50000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 50000)

    // Third ACK should work in cumulative mode
    await windowControl.updateReceivedAcknowledgement(150000)
    received = await windowControl.receivedAcknowledgement
    XCTAssertEqual(received, 150000)
  }
}
