//
//  RTMPMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

/// Protocol for handling specific RTMP message types
protocol RTMPMessageHandler: Sendable {
  /// Check if this handler can process the given message
  func canHandle(_ message: RTMPMessage) -> Bool

  /// Handle the message with provided context
  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async
}
