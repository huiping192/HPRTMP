//
//  RTMPMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

// max timestamp 0xFFFFFF
let maxTimestamp = Timestamp(16777215)

enum RTMPChunkStreamId: UInt16 {
  case control = 2
  case command = 3
  case audio = 4
  case video = 5

  var chunkStreamId: ChunkStreamId {
    ChunkStreamId(rawValue)
  }
}

public protocol RTMPMessage: Sendable {
  var timestamp: Timestamp { get }
  var messageType: MessageType { get }
  var msgStreamId: MessageStreamId { get }
  var streamId: ChunkStreamId { get }

  var payload: Data { get}

  var priority: MessagePriority { get }
}

public extension RTMPMessage {
  var priority: MessagePriority {
    .high
  }
}
