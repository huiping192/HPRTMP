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
    let pendingMessageCount = await priorityQueue.pendingMessageCount
    let pendingVideoFrames = await priorityQueue.pendingVideoFrames
    let pendingAudioFrames = await priorityQueue.pendingAudioFrames
    let pendingOtherMessages = await priorityQueue.pendingOtherMessages

    let totalBytesReceived = await windowControl.totalInBytesCount
    let totalBytesSent = await windowControl.totalOutBytesCount
    let receivedAcknowledgement = await windowControl.receivedAcknowledgement
    let windowSize = await windowControl.windowSize

    let unacknowledgedBytes = Int64(totalBytesSent) - Int64(receivedAcknowledgement)
    let windowUtilization = windowSize > 0 ? Double(unacknowledgedBytes) / Double(windowSize) : 0.0

    let mediaStats = await mediaStatistics.getStatistics()

    return TransmissionStatistics(
      pendingMessageCount: pendingMessageCount,
      totalBytesReceived: totalBytesReceived,
      totalBytesSent: totalBytesSent,
      unacknowledgedBytes: unacknowledgedBytes,
      windowSize: windowSize,
      windowUtilization: windowUtilization,
      videoFramesSent: mediaStats.videoFramesSent,
      videoKeyFramesSent: mediaStats.videoKeyFramesSent,
      audioFramesSent: mediaStats.audioFramesSent,
      videoBytesSent: mediaStats.videoBytesSent,
      audioBytesSent: mediaStats.audioBytesSent,
      videoBitrate: mediaStats.videoBitrate,
      audioBitrate: mediaStats.audioBitrate,
      currentVideoTimestamp: mediaStats.currentVideoTimestamp,
      currentAudioTimestamp: mediaStats.currentAudioTimestamp,
      pendingVideoFrames: pendingVideoFrames,
      pendingAudioFrames: pendingAudioFrames,
      pendingOtherMessages: pendingOtherMessages
    )
  }
}
