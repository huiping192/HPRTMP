//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/26.
//

import Foundation

class ControlMessage: RTMPBaseMessage {
  init(type: MessageType) {
    super.init(type: type, streamId: RTMPStreamId.control.rawValue)
  }
}

// Set Chunk Size (1)
class ChunkSizeMessage: ControlMessage {
  let size: UInt32
  init(size: UInt32) {
    self.size = size
    super.init(type: .chunkSize)
  }
  
  override var payload: Data {
    var data = Data()
    data.write(size & 0x7FFFFFFF)
    return data
  }
}


// Abort message (2)
class AbortMessage: ControlMessage {
  let chunkStreamId: UInt16
  init(chunkStreamId : UInt16) {
    self.chunkStreamId = chunkStreamId
    super.init(type: .abort)
  }
  
  override var payload: Data {
    var data = Data()
    data.write(UInt32(chunkStreamId))
    return data
  }
}


// Acknowledgement (3)
class AcknowledgementMessage: ControlMessage {
  let sequence: UInt32
  init(sequence: UInt32) {
    self.sequence = sequence
    super.init(type: .acknowledgement)
  }
  
  override var payload: Data {
    var data = Data()
    data.write(sequence)
    return data
  }
}


//Window Acknowledgement Size (5)
class WindowAckMessage: ControlMessage {
  let size: UInt32
  init(size: UInt32) {
    self.size = size
    super.init(type: .windowAcknowledgement)
  }
  
  override var payload: Data {
    var data = Data()
    data.write(size)
    return data
  }
}


//Set Peer Bandwidth (6)
class PeerBandwidthMessage: ControlMessage {
  
  enum LimitType: UInt8 {
    case hard = 0
    case soft = 1
    case dynamic = 2
  }
  
  let windowSize: UInt32
  let limit: LimitType
  init(windowSize: UInt32, limit: LimitType) {
    self.windowSize = windowSize
    self.limit = limit
    super.init(type: .peerBandwidth)
  }
  
  override var payload: Data {
    var data = Data()
    data.write(windowSize)
    data.write(limit.rawValue)
    return data
  }
}
