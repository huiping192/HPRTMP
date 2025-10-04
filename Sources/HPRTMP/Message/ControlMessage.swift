//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/26.
//

import Foundation

class ControlMessage: RTMPBaseMessage, @unchecked Sendable {
  let msgStreamId: Int
  let timestamp: UInt32
  let messageType: MessageType

  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
  var payload: Data { Data() }

  init(type: MessageType, msgStreamId: Int = 0, timestamp: UInt32 = 0) {
    self.messageType = type
    self.msgStreamId = msgStreamId
    self.timestamp = timestamp
  }
}

// Set Chunk Size (1)
struct ChunkSizeMessage: RTMPBaseMessage {
  let size: UInt32

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .chunkSize }
  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
  var payload: Data {
    var data = Data()
    data.write(size & 0x7FFFFFFF)
    return data
  }
}


// Abort message (2)
struct AbortMessage: RTMPBaseMessage {
  let chunkStreamId: UInt16

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .abort }
  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
  var payload: Data {
    var data = Data()
    data.write(UInt32(chunkStreamId))
    return data
  }
}


// Acknowledgement (3)
struct AcknowledgementMessage: RTMPBaseMessage {
  let sequence: UInt32

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .acknowledgement }
  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
  var payload: Data {
    var data = Data()
    data.write(sequence)
    return data
  }
}


//Window Acknowledgement Size (5)
struct WindowAckMessage: RTMPBaseMessage {
  let size: UInt32

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .windowAcknowledgement }
  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
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

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .peerBandwidth }
  var streamId: UInt16 { RTMPChunkStreamId.control.rawValue }
  var payload: Data {
    var data = Data()
    data.write(windowSize)
    data.write(limit.rawValue)
    return data
  }
}
