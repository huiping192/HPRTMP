
import Foundation

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
