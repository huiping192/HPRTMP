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
  private let eventDispatcher: RTMPEventDispatcher
  private let logger: Logger

  private var task: Task<Void, Never>?

  init(
    priorityQueue: MessagePriorityQueue,
    eventDispatcher: RTMPEventDispatcher,
    logger: Logger
  ) {
    self.priorityQueue = priorityQueue
    self.eventDispatcher = eventDispatcher
    self.logger = logger
  }

  /// Start monitoring with the specified interval
  /// - Parameter interval: Time interval between statistics updates (in nanoseconds)
  func start(interval: UInt64 = 1_000_000_000) {
    guard task == nil else { return }

    task = Task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: interval)

        let pendingMessageCount = await priorityQueue.pendingMessageCount
        let statistics = TransmissionStatistics(pendingMessageCount: pendingMessageCount)

        await eventDispatcher.yieldConnection(.statistics(statistics))
      }
    }
  }

  /// Stop monitoring
  func stop() {
    task?.cancel()
    task = nil
  }
}
