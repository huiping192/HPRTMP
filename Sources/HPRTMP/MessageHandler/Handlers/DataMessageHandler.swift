//
//  DataMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

/// Handles data messages (non-audio/video data)
/// Currently only logs the message, but can be extended for future functionality
struct DataMessageHandler: RTMPMessageHandler {
  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is DataMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let dataMessage = message as? DataMessage else { return }

    context.logger.info("DataMessage, message Type: \(dataMessage.messageType.rawValue)")

    // TODO: Add specific data message handling logic here when needed
  }
}
