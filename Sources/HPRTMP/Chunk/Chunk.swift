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
  var chunkPayload: Data = Data()
  
  // Initialize the ChunkHeader struct with a stream ID, message header, and chunk payload
  init(streamId: Int,messageHeader: MessageHeader, chunkPayload: Data) {
    self.messageHeader = messageHeader
    self.chunkPayload = chunkPayload
    
    // Determine the basic header type based on the type of the message header
    let basicHeaderType: MessageHeaderType
    switch messageHeader {
    case _ as MessageHeaderType0:
        basicHeaderType = .type0
    case _ as MessageHeaderType1:
        basicHeaderType = .type1
    case _ as MessageHeaderType2:
        basicHeaderType = .type2
    case _ as MessageHeaderType3:
        basicHeaderType = .type3
    default:
        // If the message header is not one of the four defined types, set the basic header type to type0
        basicHeaderType = .type0
    }
    
    // Initialize the basic header with the stream ID and type
    self.basicHeader = BasicHeader(streamId: UInt16(streamId), type: basicHeaderType)
  }
  
  // Encode the chunk header into a data object
  func encode() -> Data {
    // Concatenate the encoded basic header, message header, and chunk payload
    return basicHeader.encode() + messageHeader.encode() + chunkPayload
  }
}

extension ChunkHeader: Equatable {
  static func == (lhs: ChunkHeader, rhs: ChunkHeader) -> Bool {
    return lhs.basicHeader == rhs.basicHeader && lhs.messageHeader.encode() == rhs.messageHeader.encode() && lhs.chunkPayload == rhs.chunkPayload
  }
}

enum MessageHeaderType: Int {
    case type0 = 0
    case type1 = 1
    case type2 = 2
    case type3 = 3
}

struct BasicHeader: Equatable {
  let streamId: UInt16
  let type: MessageHeaderType
  
  func encode() -> Data {
    // Calculates the format field (fmt) by left shifting the MessageHeaderType's raw value 6 bits to the left
    let fmt = UInt8(type.rawValue << 6)
    
    // Checks if streamId is less than or equal to 63, in which case the Basic Header will only consist of one byte
    if streamId <= 63 {
      // Returns a single-byte Data object that contains the value of `fmt` ORed with the value of streamId casted to UInt8
      return Data([UInt8(fmt | UInt8(streamId))])
    }
    
    // Checks if streamId is less than or equal to 319, in which case the Basic Header will consist of two bytes
    if streamId <= 319 {
      // Returns a two-byte Data object where the first byte is the value of `fmt` ORed with 0b00000000 (0 in binary),
      // and the second byte is the value of streamId minus 64 casted to UInt8
      return Data([UInt8(fmt | 0b00000000), UInt8(streamId - 64)])
    }
    
    // If streamId is greater than 319, the Basic Header will consist of three bytes.
    // In this case, the first byte is the value of `fmt` ORed with 0b00000001 (1 in binary),
    // and the next two bytes are the value of `streamId` minus 64 in big endian byte order.
    return Data([fmt | 0b00000001] + (streamId - 64).bigEndian.data)
  }
}