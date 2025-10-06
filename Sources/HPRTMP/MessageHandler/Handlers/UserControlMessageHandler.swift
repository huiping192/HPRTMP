//
//  UserControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

/// Handles user control messages (ping, stream recording, etc.)
struct UserControlMessageHandler: RTMPMessageHandler {
  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is UserControlMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let userControlMessage = message as? UserControlMessage else { return }

    context.logger.info("UserControlMessage, message Type: \(userControlMessage.type.rawValue)")

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
