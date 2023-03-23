//
//  ChunkEncoder.swift
//  
//
//  Created by Huiping Guo on 2023/02/03.
//

import Foundation

class ChunkEncoder {
  // chunk size 128
  private static let maxChunkSize: UInt8 = 128
  
  var chunkSize = UInt32(ChunkEncoder.maxChunkSize)
  
  func chunk(message: RTMPMessage & Encodable, isFirstType0: Bool = true) -> [Chunk] {
    let payload = message.encode()
    
    return payload.split(size: Int(chunkSize))
      .enumerated()
      .map({
        // basic Header
        // Type 0 == first chunk , other use type 3
        if $0.offset == 0 {
          let messageHeader: MessageHeader
          if isFirstType0 {
            messageHeader = MessageHeaderType0(timestamp: message.timestamp,
                                               messageLength: payload.count,
                                               type: message.messageType ,
                                               messageStreamId: message.msgStreamId)
          } else {
            messageHeader = MessageHeaderType1(timestampDelta: message.timestamp,
                                               messageLength: payload.count,
                                               type: message.messageType)
          }
          
          let header = ChunkHeader(streamId: message.streamId,
                             messageHeader: messageHeader)
          
          return Chunk(chunkHeader: header, chunkData: Data($0.element))
        }
        let header = ChunkHeader(streamId: message.streamId,
                           messageHeader: MessageHeaderType3())
        return Chunk(chunkHeader: header, chunkData: Data($0.element))
      })
  }
  
  func reset() {
    
  }
}

public extension Data {
  func split(size: Int) -> [Data] {
    guard size != 0 else { return [] }
    return stride(from: 0, to: count, by: size).map({
      let end = $0 + size >= count ? count : $0 + size
      return self.subdata(in: $0 ..< end)
    })
  }
}

