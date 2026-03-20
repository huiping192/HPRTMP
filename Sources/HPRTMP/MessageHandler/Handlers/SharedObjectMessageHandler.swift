//
//  SharedObjectMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

struct SharedObjectMessageHandler: RTMPMessageHandler {
  private let logger: RTMPLogger

  init(logger: RTMPLogger = RTMPLogger(category: "SharedObjectMessageHandler")) {
    self.logger = logger
  }

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is SharedObjectMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let sharedObjectMessage = message as? SharedObjectMessage else { return }

    logger.info("ShareMessage, message Type: \(sharedObjectMessage.messageType.rawValue)")

    // TODO: Add specific shared object message handling logic here when needed
  }
}
