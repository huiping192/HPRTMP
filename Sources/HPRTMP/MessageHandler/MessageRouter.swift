//
//  MessageRouter.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

actor MessageRouter {
  private let handlers: [RTMPMessageHandler]
  private let logger: RTMPLogger

  init(handlers: [RTMPMessageHandler], logger: RTMPLogger = RTMPLogger(category: "MessageRouter")) {
    self.handlers = handlers
    self.logger = logger
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
