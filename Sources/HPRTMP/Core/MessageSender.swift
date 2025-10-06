//
//  MessageSender.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Actor responsible for sending messages through the RTMP connection
/// Handles message encoding, flow control, and bandwidth throttling
actor MessageSender {
  private let priorityQueue: MessagePriorityQueue
  private let encoder: MessageEncoder
  private let windowControl: WindowControl
  private let tokenBucket: TokenBucket
  private let sendData: @Sendable (Data) async throws -> Void
  private let logger: Logger

  private var task: Task<Void, Never>?
  private var errorHandler: (@Sendable () async -> Void)?

  init(
    priorityQueue: MessagePriorityQueue,
    encoder: MessageEncoder,
    windowControl: WindowControl,
    tokenBucket: TokenBucket,
    sendData: @escaping @Sendable (Data) async throws -> Void,
    logger: Logger
  ) {
    self.priorityQueue = priorityQueue
    self.encoder = encoder
    self.windowControl = windowControl
    self.tokenBucket = tokenBucket
    self.sendData = sendData
    self.logger = logger
  }

  /// Set the error handler to be called when sending fails
  func setErrorHandler(_ handler: @escaping @Sendable () async -> Void) {
    self.errorHandler = handler
  }

  /// Start the message sending loop
  func start() {
    guard task == nil else { return }

    task = Task {
      while !Task.isCancelled {
        guard let messageContainer = await priorityQueue.dequeue() else { break }

        let message = messageContainer.message
        let isFirstType = messageContainer.isFirstType

        // Wait if window size is reached
        if await windowControl.shouldWaitAcknowledgement {
          logger.info("[HPRTMP] Window size reached, waiting for acknowledgement...")
          await priorityQueue.requeue(messageContainer)
          try? await Task.sleep(nanoseconds: 100_000_000)  // Wait 100ms
          continue
        }

        logger.debug("send message start: \(type(of: message))")

        // Handle chunk size message specially
        if let chunkSizeMessage = message as? ChunkSizeMessage {
          do {
            try await encoder.setChunkSize(chunkSize: chunkSizeMessage.size)
          } catch {
            logger.error("[HPRTMP] Invalid chunk size: \(error.localizedDescription), using default chunk size")
          }
        }

        // Encode message to chunks
        let chunkDataList = await encoder.encode(message: message, isFirstType0: isFirstType).map { $0.encode() }

        // Send each chunk with flow control
        var sendSuccess = true
        for chunkData in chunkDataList {
          if !(await sendChunk(chunkData, messageType: type(of: message))) {
            sendSuccess = false
            break
          }
        }

        // Resume continuation after sending
        if sendSuccess {
          messageContainer.continuation?.resume()
        } else {
          // Error already handled in sendChunk, just resume continuation
          messageContainer.continuation?.resume()
          return  // Exit the loop
        }
      }
    }
  }

  /// Stop the message sending loop
  func stop() {
    task?.cancel()
    task = nil
  }

  /// Send a single chunk with token bucket rate limiting
  private func sendChunk(_ chunkData: Data, messageType: Any.Type) async -> Bool {
    var successfullySent = false

    while !successfullySent && !Task.isCancelled {
      if await tokenBucket.consume(tokensNeeded: chunkData.count) {
        logger.debug("[HPRTMP] token bucket consume: \(chunkData.count)")
        do {
          try await sendData(chunkData)
          logger.info("[HPRTMP] send message succeeded: \(messageType)")
          successfullySent = true
        } catch {
          logger.error("[HPRTMP] send message failed: \(messageType), error: \(error)")
          logger.error("[HPRTMP] Send error: \(error.localizedDescription)")

          // Notify error handler to invalidate connection
          if let errorHandler = errorHandler {
            await errorHandler()
          }
          return false
        }
      } else {
        let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: chunkData.count)
        logger.info("[HPRTMP] token bucket is empty, waiting \(waitTime / 1_000_000)ms...")
        try? await Task.sleep(nanoseconds: waitTime)
      }
    }

    return successfullySent
  }
}
