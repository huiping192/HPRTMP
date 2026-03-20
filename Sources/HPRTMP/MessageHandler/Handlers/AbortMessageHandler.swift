//
//  AbortMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

struct AbortMessageHandler: RTMPMessageHandler {
  private let logger: RTMPLogger

  init(logger: RTMPLogger = RTMPLogger(category: "AbortMessageHandler")) {
    self.logger = logger
  }

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is AbortMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let abortMessage = message as? AbortMessage else { return }

    logger.info("AbortMessage, message Type: \(abortMessage.chunkStreamId)")

    // TODO: Add specific abort message handling logic here when needed
    // This could involve cleaning up resources for the aborted chunk stream
  }
}
