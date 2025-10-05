
import Foundation

enum MessageHeaderType: UInt8 {
  case type0 = 0
  case type1 = 1
  case type2 = 2
  case type3 = 3
}
struct BasicHeader: Equatable {
  let streamId: ChunkStreamId
  let type: MessageHeaderType

  func encode() -> Data {
    let fmt = UInt8(type.rawValue << 6)
    let streamIdValue = streamId.value
    if streamIdValue <= 63 {
      return Data([UInt8(fmt | UInt8(streamIdValue))])
    }
    if streamIdValue <= 319 {
      return Data([UInt8(fmt | 0b00000000), UInt8(streamIdValue - 64)])
    }
    return Data([fmt | 0b00000001] + (streamIdValue - 64).bigEndian.data)
  }
}
