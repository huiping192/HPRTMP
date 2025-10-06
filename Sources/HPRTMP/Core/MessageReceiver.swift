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
  private let logger: Logger

  private var task: Task<Void, Never>?
  private var messageHandler: (@Sendable (Data) async -> Void)?

  init(
    receiveData: @escaping @Sendable () async throws -> Data,
    windowControl: WindowControl,
    decoder: MessageDecoder,
    logger: Logger
  ) {
    self.receiveData = receiveData
    self.windowControl = windowControl
    self.decoder = decoder
    self.logger = logger
  }

  /// Set the handler to be called when data is received
  func setMessageHandler(_ handler: @escaping @Sendable (Data) async -> Void) {
    self.messageHandler = handler
  }

  /// Start the message receiving loop
  func start() {
    guard task == nil else { return }

    task = Task {
      while !Task.isCancelled {
        do {
          let data = try await receiveData()
          logger.debug("receive data count: \(data.count)")
          if let messageHandler = messageHandler {
            await messageHandler(data)
          }
        } catch {
          logger.error("[HPRTMP] receive message failed: error: \(error)")
          return
        }
      }
    }
  }

  /// Stop the message receiving loop
  func stop() {
    task?.cancel()
    task = nil
  }
}
