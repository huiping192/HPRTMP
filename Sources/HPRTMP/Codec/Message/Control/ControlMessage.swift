//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/26.
//

import Foundation

class ControlMessage: RTMPBaseMessage, @unchecked Sendable {
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp
  let messageType: MessageType

  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data { Data() }

  init(type: MessageType, msgStreamId: MessageStreamId = .zero, timestamp: Timestamp = .zero) {
    self.messageType = type
    self.msgStreamId = msgStreamId
    self.timestamp = timestamp
  }
}

// Set Chunk Size (1)
struct ChunkSizeMessage: RTMPBaseMessage {
  let size: UInt32

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .chunkSize }
  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data {
    var data = Data()
    data.write(size & 0x7FFFFFFF)
    return data
  }
}


// Abort message (2)
struct AbortMessage: RTMPBaseMessage {
  let chunkStreamId: UInt16

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .abort }
  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data {
    var data = Data()
    data.write(UInt32(chunkStreamId))
    return data
  }
}


// Acknowledgement (3)
struct AcknowledgementMessage: RTMPBaseMessage {
  let sequence: UInt32

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .acknowledgement }
  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data {
    var data = Data()
    data.write(sequence)
    return data
  }
}


//Window Acknowledgement Size (5)
struct WindowAckMessage: RTMPBaseMessage {
  let size: UInt32

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .windowAcknowledgement }
  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data {
    var data = Data()
    data.write(size)
    return data
  }
}


//Set Peer Bandwidth (6)
struct PeerBandwidthMessage: RTMPBaseMessage {

  enum LimitType: UInt8 {
    case hard = 0
    case soft = 1
    case dynamic = 2
  }

  let windowSize: UInt32
  let limit: LimitType

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .peerBandwidth }
  var streamId: ChunkStreamId { RTMPChunkStreamId.control.chunkStreamId }
  var payload: Data {
    var data = Data()
    data.write(windowSize)
    data.write(limit.rawValue)
    return data
  }
}
