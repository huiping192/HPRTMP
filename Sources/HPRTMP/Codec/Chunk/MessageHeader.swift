import Foundation

protocol MessageHeader: RTMPEncodable, Sendable {
}

extension MessageHeader where Self: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.encode() == rhs.encode()
  }
}

struct MessageHeaderType0: MessageHeader {
  // max timestamp 0xFFFFFF
  let maxTimestampValue = Timestamp(16777215)

  let timestamp: Timestamp
  let messageLength: Int
  let type: MessageType
  let messageStreamId: MessageStreamId

  func encode() -> Data {
    var data = Data()
    let isExtendTime = timestamp > maxTimestampValue
    let time = isExtendTime ? maxTimestampValue.value : timestamp.value
    data.writeU24(UInt32(time), bigEndian: true)
    data.writeU24(UInt32(messageLength), bigEndian: true)
    data.append(type.rawValue)
    data.append(UInt32(messageStreamId.value).data) // little-endian

    if isExtendTime {
      data.append(timestamp.value.bigEndian.data)
    }
    return data
  }
}

struct MessageHeaderType1: MessageHeader {
  let timestampDelta: Timestamp
  let messageLength: Int
  let type: MessageType

  func encode() -> Data {
    var data = Data()
    data.writeU24(timestampDelta.value, bigEndian: true)
    data.writeU24(UInt32(messageLength), bigEndian: true)
    data.write(type.rawValue)
    return data
  }
}

struct MessageHeaderType2: MessageHeader {
  let timestampDelta: Timestamp

  func encode() -> Data {
    var data = Data()
    data.writeU24(timestampDelta.value, bigEndian: true)
    return data
  }
}
struct MessageHeaderType3: MessageHeader {
  func encode() -> Data {
      return Data()
  }
}
