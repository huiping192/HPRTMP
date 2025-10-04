
import Foundation

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
    
    self.basicHeader = BasicHeader(streamId: streamId, type: basicHeaderType)
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
