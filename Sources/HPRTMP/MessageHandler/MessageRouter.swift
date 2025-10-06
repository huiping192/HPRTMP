//
//  MessageRouter.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Routes RTMP messages to appropriate handlers
actor MessageRouter {
  private let handlers: [RTMPMessageHandler]
  private let logger: Logger

  init(handlers: [RTMPMessageHandler]) {
    self.handlers = handlers
    self.logger = Logger(subsystem: "HPRTMP", category: "MessageRouter")
  }

  /// Route a message to the first handler that can handle it
  func route(_ message: RTMPMessage, context: MessageHandlerContext) async {
    for handler in handlers {
      if handler.canHandle(message) {
        await handler.handle(message, context: context)
        return
      }
    }

    // No handler found for this message type
    logger.warning("No handler found for message type: \(type(of: message))")
  }
}
