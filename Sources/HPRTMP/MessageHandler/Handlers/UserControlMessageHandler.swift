//
//  UserControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

struct UserControlMessageHandler: RTMPMessageHandler {
  private let logger: RTMPLogger

  init(logger: RTMPLogger = RTMPLogger(category: "UserControlMessageHandler")) {
    self.logger = logger
  }

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is UserControlMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let userControlMessage = message as? UserControlMessage else { return }

    logger.info("UserControlMessage, message Type: \(userControlMessage.type.rawValue)")

    switch userControlMessage.type {
    case .pingRequest:
      await context.eventDispatcher.yieldStream(.pingRequest(userControlMessage.data))

    case .streamIsRecorded:
      await context.eventDispatcher.yieldStream(.record)

    default:
      // Other user control events are not handled yet
      break
    }
  }
}
