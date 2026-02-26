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
    // Prevent multiple concurrent receive loops; task == nil is the single source of truth
    guard task == nil else {
      logger.debug("MessageReceiver already running, ignoring start() call")
      return
    }

    task = Task {
      while !Task.isCancelled {
        do {
          let data = try await receiveData()
          logger.debug("receive data count: \(data.count)")

          if let handler = messageHandler {
            await handler(data)
          }
        } catch {
          logger.error("[HPRTMP] receive message failed: error: \(error)")

          if let handler = errorHandler {
            await handler(error)
          }

          return
        }
      }
    }
  }

  /// Stop the message receiving loop
  /// - Note: This method waits for the receive loop to fully terminate before returning
  func stop() async {
    task?.cancel()
    await task?.value
    task = nil
  }
}
