import Foundation

actor WindowControl {

  private let logger: RTMPLogger

  private(set) var windowSize: UInt32 = 2500000  // default: 2.4mb

  private(set) var totalInBytesCount: UInt64 = 0
  private(set) var totalInBytesSeq: UInt64 = 1

  private(set) var totalOutBytesCount: UInt64 = 0
  private(set) var totalOutBytesSeq: UInt64 = 1

  private(set) var inBytesWindowEvent: (@Sendable (UInt32) async -> Void)? = nil
  private(set) var receivedAcknowledgement: UInt64 = 0

  let ackTimeout: TimeInterval
  private var waitingSinceDate: Date? = nil
  private(set) var ackDisabled: Bool = false

  init(ackTimeout: TimeInterval = 5.0, logger: RTMPLogger = RTMPLogger(category: "WindowControl")) {
    self.ackTimeout = ackTimeout
    self.logger = logger
  }

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
    // Server is ACKing — re-enable flow control in case it was auto-disabled by timeout
    ackDisabled = false
    waitingSinceDate = nil

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
      receivedAcknowledgement = UInt64(size)
      return
    }

    // Second ACK determines the mode
    if size == lastReceivedAcknowledgement {
      ackMode = .incremental
      receivedAcknowledgement += UInt64(size)
      logger.info("[WindowControl] Detected incremental ACK mode (YouTube)")
    } else if size > lastReceivedAcknowledgement {
      ackMode = .cumulative
      receivedAcknowledgement = UInt64(size)
      logger.info("[WindowControl] Detected cumulative ACK mode (SRS/NDS)")
    } else {
      ackMode = .cumulative
      receivedAcknowledgement = UInt64(size)
      logger.warning("[WindowControl] ACK decreased, defaulting to cumulative mode")
    }
  }

  private func handleIncrementalMode(_ size: UInt32) {
    receivedAcknowledgement += UInt64(size)

    if size != lastReceivedAcknowledgement {
      logger.warning("[WindowControl] Increment value changed: \(self.lastReceivedAcknowledgement) → \(size)")
    }
  }

  private func handleCumulativeMode(_ size: UInt32) {
    if UInt64(size) < receivedAcknowledgement {
      logger.warning("[WindowControl] ACK decreased, ignoring: \(size) < \(self.receivedAcknowledgement)")
      return
    }

    receivedAcknowledgement = UInt64(size)
  }

  func addInBytesCount(_ count: UInt32) async {
    totalInBytesCount += UInt64(count)
    if totalInBytesCount >= UInt64(windowSize) * totalInBytesSeq {
      await inBytesWindowEvent?(UInt32(truncatingIfNeeded: totalInBytesCount))
      totalInBytesSeq += 1
    }
  }

  func addOutBytesCount(_ count: UInt32) {
    totalOutBytesCount += UInt64(count)
    if totalOutBytesCount >= UInt64(windowSize) * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }

  var shouldWaitAcknowledgement: Bool {
    if ackDisabled { return false }

    let exceeded = Int64(totalOutBytesCount) - Int64(receivedAcknowledgement) >= Int64(windowSize)

    if !exceeded {
      waitingSinceDate = nil
      return false
    }

    if waitingSinceDate == nil {
      waitingSinceDate = Date()
    }

    if let start = waitingSinceDate,
       Date().timeIntervalSince(start) >= ackTimeout {
      ackDisabled = true
      logger.warning("[WindowControl] ACK timeout, disabling outbound flow control")
      waitingSinceDate = nil
      return false
    }

    return true
  }
}
