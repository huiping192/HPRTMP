//
//  ControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

/// Handles control messages
/// Currently only logs the message, but can be extended for future functionality
struct ControlMessageHandler: RTMPMessageHandler {
  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is ControlMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let controlMessage = message as? ControlMessage else { return }

    context.logger.info("ControlMessage, message Type: \(controlMessage.messageType.rawValue)")

    // TODO: Add specific control message handling logic here when needed
  }
}
