//
//  DataMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles data messages (non-audio/video data)
/// Currently only logs the message, but can be extended for future functionality
struct DataMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "DataMessageHandler")

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is DataMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let dataMessage = message as? DataMessage else { return }

    logger.info("DataMessage, message Type: \(dataMessage.messageType.rawValue)")

    // TODO: Add specific data message handling logic here when needed
  }
}
