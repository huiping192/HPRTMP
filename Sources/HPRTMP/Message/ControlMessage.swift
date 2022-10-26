//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/26.
//

import Foundation

// Set Chunk Size (1)
class ChunkSizeMessage: Encodable {
  let size: UInt32
  init(size: UInt32) {
    self.size = size
  }
  
  func encode() -> Data {
    var data = Data()
    data.write(size & 0x7FFFFFFF)
    return data
  }
}


// Abort message (2)
class AbortMessage: Encodable {
    let chunkStreamId: Int
    init(chunkStreamId : Int) {
        self.chunkStreamId = chunkStreamId
    }
    
    func encode() -> Data {
        var data = Data()
        data.write(UInt32(chunkStreamId))
        return data
    }
}


// Acknowledgement (3)
class AcknowledgementMessage: Encodable {
    let sequence: UInt32
    init(sequence: UInt32) {
        self.sequence = sequence
    }
    
    func encode() -> Data {
        var data = Data()
        data.write(sequence)
        return data
    }
}


//Window Acknowledgement Size (5)
class WindowAckMessage: Encodable {
    let size: UInt32
    init(size: UInt32) {
        self.size = size
    }
    
    func encode() -> Data {
        var data = Data()
        data.write(size)
        return data
    }
}


//Set Peer Bandwidth (6)
class PeerBandwidthMessage: Encodable {
    
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
    }
    
    func encode() -> Data {
        var data = Data()
        data.write(windowSize)
        data.write(limit.rawValue)
        return data
    }
}
