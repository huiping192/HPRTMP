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


