import Foundation

protocol RTMPEncodable {
  func encode() -> Data
}

struct Chunk: RTMPEncodable, Equatable {
  let chunkHeader: ChunkHeader
  var chunkData: Data
  
  func encode() -> Data {
    return chunkHeader.encode() + chunkData
  }
  
  static func == (lhs: Chunk, rhs: Chunk) -> Bool {
    return lhs.chunkHeader == rhs.chunkHeader && lhs.chunkData == rhs.chunkData
  }
}

struct ChunkHeader: RTMPEncodable {
  let basicHeader: BasicHeader
  let messageHeader: MessageHeader
  
  init(basicHeader: BasicHeader, messageHeader: MessageHeader) {
    self.basicHeader = basicHeader
    self.messageHeader = messageHeader
  }
  
  // Initialize the ChunkHeader struct with a stream ID, message header, and chunk payload
  init(streamId: UInt16,messageHeader: MessageHeader) {
    self.messageHeader = messageHeader
    
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
        basicHeaderType = .type0
    }
    
    // Initialize the basic header with the stream ID and type
    self.basicHeader = BasicHeader(streamId: UInt16(streamId), type: basicHeaderType)
  }
  
  func encode() -> Data {
    return basicHeader.encode() + messageHeader.encode()
  }
}

extension ChunkHeader: Equatable {
  static func == (lhs: ChunkHeader, rhs: ChunkHeader) -> Bool {
    return lhs.basicHeader == rhs.basicHeader && lhs.messageHeader.encode() == rhs.messageHeader.encode()
  }
}

enum MessageHeaderType: UInt8 {
  case type0 = 0
  case type1 = 1
  case type2 = 2
  case type3 = 3
}
struct BasicHeader: Equatable {
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
    return Data([fmt | 0b00000001] + (streamId - 64).bigEndian.data)
  }
}
