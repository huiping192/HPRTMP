//
//  ControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

struct ControlMessageHandler: RTMPMessageHandler {
  private let logger: RTMPLogger

  init(logger: RTMPLogger = RTMPLogger(category: "ControlMessageHandler")) {
    self.logger = logger
  }

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is ControlMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let controlMessage = message as? ControlMessage else { return }

    logger.info("ControlMessage, message Type: \(controlMessage.messageType.rawValue)")

    // TODO: Add specific control message handling logic here when needed
  }
}
