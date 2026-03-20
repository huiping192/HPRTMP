//
//  TransmissionMonitor.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Actor responsible for monitoring transmission statistics
/// Periodically collects and reports statistics through the event dispatcher
actor TransmissionMonitor {
  private let priorityQueue: MessagePriorityQueue
  private let windowControl: WindowControl
  private let mediaStatistics: MediaStatisticsCollector
  private let eventDispatcher: RTMPEventDispatcher
  private let logger = Logger(subsystem: "HPRTMP", category: "TransmissionMonitor")

  private var task: Task<Void, Never>?

  init(
    priorityQueue: MessagePriorityQueue,
    windowControl: WindowControl,
    mediaStatistics: MediaStatisticsCollector,
    eventDispatcher: RTMPEventDispatcher
  ) {
    self.priorityQueue = priorityQueue
    self.windowControl = windowControl
    self.mediaStatistics = mediaStatistics
    self.eventDispatcher = eventDispatcher
  }

  /// Start monitoring with the specified interval
  /// - Parameter interval: Time interval between statistics updates (in nanoseconds)
  func start(interval: UInt64 = 1_000_000_000) {
    guard task == nil else { return }

    task = Task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: interval)

        let statistics = await collectStatistics()
        await eventDispatcher.yieldConnection(.statistics(statistics))
      }
    }
  }

  /// Stop monitoring
  func stop() {
    task?.cancel()
    task = nil
  }

  private func collectStatistics() async -> TransmissionStatistics {
    // Use async let to collect statistics in parallel for better performance
    async let pendingMessages: (pendingMessageCount: Int, pendingVideoFrames: Int, pendingAudioFrames: Int, pendingOtherMessages: Int) = collectPendingMessages()
    async let windowStats: (totalIn: UInt32, totalOut: UInt32, ack: UInt32, windowSize: UInt32) = collectWindowStats()
    async let mediaStats: (videoFramesSent: UInt64, videoKeyFramesSent: UInt64, audioFramesSent: UInt64, videoBytesSent: UInt64, audioBytesSent: UInt64, videoBitrate: Double, audioBitrate: Double, currentVideoTimestamp: UInt32, currentAudioTimestamp: UInt32) = mediaStatistics.getStatistics()

    let pending = await pendingMessages
    let window = await windowStats
    let media = await mediaStats

    // Ensure unacknowledgedBytes is never negative (handles edge case when ack > sent)
    let unacknowledgedBytes = max(0, Int64(window.totalOut) - Int64(window.ack))
    let windowUtilization = window.windowSize > 0 ? Double(unacknowledgedBytes) / Double(window.windowSize) : 0.0

    return TransmissionStatistics(
      pendingMessageCount: pending.pendingMessageCount,
      totalBytesReceived: window.totalIn,
      totalBytesSent: window.totalOut,
      unacknowledgedBytes: unacknowledgedBytes,
      windowSize: window.windowSize,
      windowUtilization: windowUtilization,
      videoFramesSent: media.videoFramesSent,
      videoKeyFramesSent: media.videoKeyFramesSent,
      audioFramesSent: media.audioFramesSent,
      videoBytesSent: media.videoBytesSent,
      audioBytesSent: media.audioBytesSent,
      videoBitrate: media.videoBitrate,
      audioBitrate: media.audioBitrate,
      currentVideoTimestamp: media.currentVideoTimestamp,
      currentAudioTimestamp: media.currentAudioTimestamp,
      pendingVideoFrames: pending.pendingVideoFrames,
      pendingAudioFrames: pending.pendingAudioFrames,
      pendingOtherMessages: pending.pendingOtherMessages
    )
  }

  private func collectPendingMessages() async -> (pendingMessageCount: Int, pendingVideoFrames: Int, pendingAudioFrames: Int, pendingOtherMessages: Int) {
    let pendingMessageCount = await priorityQueue.pendingMessageCount
    let pendingVideoFrames = await priorityQueue.pendingVideoFrames
    let pendingAudioFrames = await priorityQueue.pendingAudioFrames
    let pendingOtherMessages = await priorityQueue.pendingOtherMessages
    return (pendingMessageCount, pendingVideoFrames, pendingAudioFrames, pendingOtherMessages)
  }

  private func collectWindowStats() async -> (totalIn: UInt32, totalOut: UInt32, ack: UInt32, windowSize: UInt32) {
    let totalBytesReceived = await windowControl.totalInBytesCount
    let totalBytesSent = await windowControl.totalOutBytesCount
    let receivedAcknowledgement = await windowControl.receivedAcknowledgement
    let windowSize = await windowControl.windowSize
    return (totalBytesReceived, totalBytesSent, receivedAcknowledgement, windowSize)
  }
}
