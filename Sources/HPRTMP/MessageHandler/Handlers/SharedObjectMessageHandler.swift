//
//  SharedObjectMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles shared object messages
/// Currently only logs the message, but can be extended for future functionality
struct SharedObjectMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "SharedObjectMessageHandler")

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is SharedObjectMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let sharedObjectMessage = message as? SharedObjectMessage else { return }

    logger.info("ShareMessage, message Type: \(sharedObjectMessage.messageType.rawValue)")

    // TODO: Add specific shared object message handling logic here when needed
  }
}
