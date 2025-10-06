import Foundation

/// Represents the current status of an RTMP publishing session
public enum RTMPPublishStatus: Equatable, Sendable {
  /// Initial state before any connection attempt
  case unknown

  /// Handshake process has started
  case handShakeStart

  /// Handshake completed successfully
  case handShakeDone

  /// Connected to RTMP server
  case connect

  /// Publishing has started successfully
  case publishStart

  /// Session failed with an error
  case failed(err: RTMPError)

  /// Session disconnected
  case disconnected
}
