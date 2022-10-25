//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/24.
//

import Foundation

protocol Encodable {
  func encode() -> Data
}

struct Chunk: Encodable {
  let chunkHeader: ChunkHeader
  let chunkData: Data
  
  func encode() -> Data {
    return chunkHeader.encode() + chunkData
  }
}


struct ChunkHeader: Encodable {
  let basicHeader: BasicHeader
  let messageHeader: MessageHeader
  let extendedTimestamp: TimeInterval
  
  func encode() -> Data {
    return basicHeader.encode() + messageHeader.encode()
  }
}

enum MessageHeaderType: Int {
    case type0 = 0
    case type1 = 1
    case type2 = 2
    case type3 = 3
}

struct BasicHeader {
  let streamId: UInt16
  let type: MessageHeaderType
  
  func encode() -> Data {
    let fmt = UInt8(type.rawValue << 6)
    
    if streamId <= 63 {
      return Data([UInt8(fmt | UInt8(streamId))])
    }
    
    if streamId <= 319 {
      return Data([UInt8(fmt | 0b00000000), UInt8(streamId - 64)])
    }
    // Basic Header是采用小端存储的方式，越往后的字节数量级越高，因此通过3个字节的每一个bit的值来计算CSID时，应该是: <第三个字节的值> * 256 + <第二个字节的值> + 64.
    // 使用bigEndian
    return Data([fmt | 0b00000001] + (streamId - 64).bigEndian.data)
  }
}
