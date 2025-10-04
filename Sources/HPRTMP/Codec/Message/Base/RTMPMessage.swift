//
//  RTMPMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

// max timestamp 0xFFFFFF
let maxTimestamp: UInt32 = 16777215

enum RTMPChunkStreamId: UInt16 {
  case control = 2
  case command = 3
  case audio = 4
  case video = 5
}

public protocol RTMPMessage: Sendable {
  var timestamp: UInt32 { get }
  var messageType: MessageType { get }
  var msgStreamId: Int  { get }
  var streamId: UInt16  { get }

  var payload: Data { get}

  var priority: MessagePriority { get }
}

public extension RTMPMessage {
  var priority: MessagePriority {
    .high
  }
}
