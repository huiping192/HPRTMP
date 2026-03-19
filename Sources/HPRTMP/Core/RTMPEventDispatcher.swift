//
//  RTMPEventDispatcher.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

/// Centralized event dispatcher for RTMP events
/// Manages all AsyncStream continuations and provides type-safe event emission
actor RTMPEventDispatcher {
  private let mediaContinuation: AsyncStream<RTMPMediaEvent>.Continuation
  private let streamContinuation: AsyncStream<RTMPStreamEvent>.Continuation
  private let connectionContinuation: AsyncStream<RTMPConnectionEvent>.Continuation

  init(
    mediaContinuation: AsyncStream<RTMPMediaEvent>.Continuation,
    streamContinuation: AsyncStream<RTMPStreamEvent>.Continuation,
    connectionContinuation: AsyncStream<RTMPConnectionEvent>.Continuation
  ) {
    self.mediaContinuation = mediaContinuation
    self.streamContinuation = streamContinuation
    self.connectionContinuation = connectionContinuation
  }

  /// Yield a media event (audio, video, metadata)
  func yieldMedia(_ event: RTMPMediaEvent) {
    mediaContinuation.yield(event)
  }

  /// Yield a stream event (publish, play, pause, etc.)
  func yieldStream(_ event: RTMPStreamEvent) {
    streamContinuation.yield(event)
  }

  /// Yield a connection event (bandwidth, statistics, disconnection)
  func yieldConnection(_ event: RTMPConnectionEvent) {
    connectionContinuation.yield(event)
  }

  /// Finish all streams to signal no more events will be produced.
  /// Must be called after connection invalidation so consumers' `for await` loops can terminate.
  func finish() {
    mediaContinuation.finish()
    streamContinuation.finish()
    connectionContinuation.finish()
  }
}
