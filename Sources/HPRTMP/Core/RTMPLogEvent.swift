import Foundation

public enum RTMPLogLevel: Int, Sendable, Comparable {
  case debug = 0, info = 1, warning = 2, error = 3
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct RTMPLogEvent: Sendable {
  public let timestamp: Date
  public let level: RTMPLogLevel
  public let category: String
  public let message: String
}
