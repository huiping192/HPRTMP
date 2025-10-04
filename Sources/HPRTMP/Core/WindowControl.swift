import Foundation
import os

actor WindowControl {

  private let logger = Logger(subsystem: "HPRTMP", category: "WindowControl")

  private(set) var windowSize: UInt32 = 2500000  // default: 2.4mb

  private(set) var totalInBytesCount: UInt32 = 0
  private(set) var totalInBytesSeq: UInt32 = 1

  private(set) var totalOutBytesCount: UInt32 = 0
  private(set) var totalOutBytesSeq: UInt32 = 1

  private(set) var inBytesWindowEvent: (@Sendable (UInt32) async -> Void)? = nil
  private(set) var receivedAcknowledgement: UInt32 = 0

  func setInBytesWindowEvent(_ inBytesWindowEvent: (@Sendable (UInt32) async -> Void)?) {
    self.inBytesWindowEvent = inBytesWindowEvent
  }

  func setWindowSize(_ size: UInt32) {
    self.windowSize = size
  }

  private var lastReceivedAcknowledgement: UInt32 = 0
  private var ackCount: Int = 0
  private var ackMode: AckMode = .detecting

  private enum AckMode {
    case detecting      // First 2 ACKs to determine server behavior
    case incremental    // YouTube: sends fixed increment value
    case cumulative     // SRS/NDS: sends cumulative byte count
  }

  func updateReceivedAcknowledgement(_ size: UInt32) {
    ackCount += 1

    switch ackMode {
    case .detecting:
      handleDetection(size)
    case .incremental:
      handleIncrementalMode(size)
    case .cumulative:
      handleCumulativeMode(size)
    }

    lastReceivedAcknowledgement = size
  }

  // MARK: - Private Methods

  private func handleDetection(_ size: UInt32) {
    if ackCount == 1 {
      receivedAcknowledgement = size
      return
    }

    // Second ACK determines the mode
    if size == lastReceivedAcknowledgement {
      ackMode = .incremental
      receivedAcknowledgement += size
      logger.info("[WindowControl] Detected incremental ACK mode (YouTube)")
    } else if size > lastReceivedAcknowledgement {
      ackMode = .cumulative
      receivedAcknowledgement = size
      logger.info("[WindowControl] Detected cumulative ACK mode (SRS/NDS)")
    } else {
      ackMode = .cumulative
      receivedAcknowledgement = size
      logger.warning("[WindowControl] ACK decreased, defaulting to cumulative mode")
    }
  }

  private func handleIncrementalMode(_ size: UInt32) {
    receivedAcknowledgement += size

    if size != lastReceivedAcknowledgement {
      logger.warning("[WindowControl] Increment value changed: \(self.lastReceivedAcknowledgement) → \(size)")
    }
  }

  private func handleCumulativeMode(_ size: UInt32) {
    if size < receivedAcknowledgement {
      logger.warning("[WindowControl] ACK decreased, ignoring: \(size) < \(self.receivedAcknowledgement)")
      return
    }

    receivedAcknowledgement = size
  }

  func addInBytesCount(_ count: UInt32) async {
    totalInBytesCount += count
    if totalInBytesCount >= windowSize * totalInBytesSeq {
      await inBytesWindowEvent?(totalInBytesCount)
      totalInBytesSeq += 1
    }
  }

  func addOutBytesCount(_ count: UInt32) {
    totalOutBytesCount += count
    if totalOutBytesCount >= windowSize * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }

  var shouldWaitAcknowledgement: Bool {
    Int64(totalOutBytesCount) - Int64(receivedAcknowledgement) >= windowSize
  }
}
