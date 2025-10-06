//
//  AbortMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles abort messages
/// Currently only logs the message, but can be extended for future functionality
struct AbortMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "AbortMessageHandler")

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is AbortMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let abortMessage = message as? AbortMessage else { return }

    logger.info("AbortMessage, message Type: \(abortMessage.chunkStreamId)")

    // TODO: Add specific abort message handling logic here when needed
    // This could involve cleaning up resources for the aborted chunk stream
  }
}
