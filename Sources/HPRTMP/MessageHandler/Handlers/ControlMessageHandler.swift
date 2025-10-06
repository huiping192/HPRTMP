//
//  ControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles control messages
/// Currently only logs the message, but can be extended for future functionality
struct ControlMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "ControlMessageHandler")

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is ControlMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let controlMessage = message as? ControlMessage else { return }

    logger.info("ControlMessage, message Type: \(controlMessage.messageType.rawValue)")

    // TODO: Add specific control message handling logic here when needed
  }
}
