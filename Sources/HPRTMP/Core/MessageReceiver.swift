//
//  MessageReceiver.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Actor responsible for receiving data from the RTMP connection
/// Handles data reception, decoding, and message dispatching
actor MessageReceiver {
  private let receiveData: @Sendable () async throws -> Data
  private let windowControl: WindowControl
  private let decoder: MessageDecoder
  private let logger = Logger(subsystem: "HPRTMP", category: "MessageReceiver")

  private var task: Task<Void, Never>?
  private var isRunning = false
  private var messageHandler: (@Sendable (Data) async -> Void)?
  private var errorHandler: (@Sendable (Error) async -> Void)?

  init(
    receiveData: @escaping @Sendable () async throws -> Data,
    windowControl: WindowControl,
    decoder: MessageDecoder
  ) {
    self.receiveData = receiveData
    self.windowControl = windowControl
    self.decoder = decoder
  }

  /// Set the handler to be called when data is received
  func setMessageHandler(_ handler: @escaping @Sendable (Data) async -> Void) {
    self.messageHandler = handler
  }

  /// Set the handler to be called when an error occurs during reception
  func setErrorHandler(_ handler: @escaping @Sendable (Error) async -> Void) {
    self.errorHandler = handler
  }

  /// Start the message receiving loop
  /// - Note: This method is idempotent - calling it multiple times has no effect if already running
  func start() {
    // Prevent multiple concurrent receive loops
    guard !isRunning else {
      logger.debug("MessageReceiver already running, ignoring start() call")
      return
    }

    isRunning = true

    task = Task { [weak self] in
      guard let self else { return }

      defer {
        Task { [weak self] in
          await self?.markStopped()
        }
      }

      while !Task.isCancelled {
        do {
          let data = try await self.receiveData()
          self.logger.debug("receive data count: \(data.count)")

          // Read the latest messageHandler on each iteration
          let handler = await self.messageHandler
          if let handler {
            await handler(data)
          }
        } catch {
          self.logger.error("[HPRTMP] receive message failed: error: \(error)")

          // Notify error handler if set
          let errorHandler = await self.errorHandler
          if let errorHandler {
            await errorHandler(error)
          }

          // Exit loop on error
          return
        }
      }
    }
  }

  /// Stop the message receiving loop
  /// - Note: This method waits for the receive loop to fully terminate
  func stop() async {
    guard let currentTask = task else { return }

    isRunning = false
    currentTask.cancel()

    // Wait for task to complete cleanup
    await currentTask.value

    task = nil
  }

  // MARK: - Private Helpers

  private func markStopped() {
    isRunning = false
  }
}
