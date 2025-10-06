//
//  MessageHandlerContext.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Context containing all dependencies needed by message handlers
/// Passed to handlers to access RTMPConnection's internal state without tight coupling
struct MessageHandlerContext: Sendable {
  // MARK: - Flow Control Dependencies

  /// Window control for managing acknowledgements and window size
  let windowControl: WindowControl

  /// Token bucket for bandwidth throttling
  let tokenBucket: TokenBucket

  /// Message decoder for updating chunk size
  let decoder: MessageDecoder

  // MARK: - State Management

  /// Message holder for tracking pending requests
  let messageHolder: MessageHolder

  // MARK: - Event Dispatching

  /// Event dispatcher for emitting events to AsyncStreams
  let eventDispatcher: RTMPEventDispatcher

  // MARK: - Continuation Management

  /// Resume the connect continuation with result
  let resumeConnect: @Sendable (Result<Void, Error>) -> Void

  /// Resume the create stream continuation with transaction ID and result
  let resumeCreateStream: @Sendable (Int, Result<Int, Error>) -> Void

  /// Update the RTMPConnection status
  let updateStatus: @Sendable (RTMPStatus) -> Void
}
