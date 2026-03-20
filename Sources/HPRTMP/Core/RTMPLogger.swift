import Foundation
import os

public struct RTMPLogger: Sendable {
  private let osLogger: Logger
  let continuation: AsyncStream<RTMPLogEvent>.Continuation?
  let category: String

  init(category: String, continuation: AsyncStream<RTMPLogEvent>.Continuation? = nil) {
    self.category = category
    self.osLogger = Logger(subsystem: "HPRTMP", category: category)
    self.continuation = continuation
  }

  func debug(_ message: String) {
    osLogger.debug("\(message)")
    continuation?.yield(RTMPLogEvent(timestamp: Date(), level: .debug, category: category, message: message))
  }

  func info(_ message: String) {
    osLogger.info("\(message)")
    continuation?.yield(RTMPLogEvent(timestamp: Date(), level: .info, category: category, message: message))
  }

  func warning(_ message: String) {
    osLogger.warning("\(message)")
    continuation?.yield(RTMPLogEvent(timestamp: Date(), level: .warning, category: category, message: message))
  }

  func error(_ message: String) {
    osLogger.error("\(message)")
    continuation?.yield(RTMPLogEvent(timestamp: Date(), level: .error, category: category, message: message))
  }
}
