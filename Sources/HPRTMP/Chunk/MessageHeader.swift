//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/25.
//

import Foundation

protocol MessageHeader: Encodable {
}

extension MessageHeader where Self: Equatable {
  static func == (lhs: MessageHeader, rhs: MessageHeader) -> Bool {
    lhs.encode() == rhs.encode()
  }
}

struct MessageHeaderType0: MessageHeader {
  // max timestamp 0xFFFFFF
  let maxTimestamp: TimeInterval = 16777215
  
  let timestamp: TimeInterval
  let messageLength: Int
  let type: MessageType
  let messageStreamId: Int
  
  func encode() -> Data {
    var data = Data()
    let isExtendTime = timestamp > maxTimestamp
    let time = isExtendTime ?  maxTimestamp : timestamp
    data.writeU24(Int(time), bigEndian: true)
    data.writeU24(messageLength, bigEndian: true)
    data.append(type.rawValue)
    data.append(UInt32(messageStreamId).data)

    if isExtendTime {
      data.append(UInt32(Int(timestamp)).bigEndian.data)
    }
    return data
  }
}

struct MessageHeaderType1: MessageHeader {
  let timestampDelta: TimeInterval
  let messageLength: Int
  let type: MessageType
  
  func encode() -> Data {
    var data = Data()
    data.append(UInt32(timestampDelta).bigEndian.data)
    data.append(UInt32(messageLength).bigEndian.data)
    data.write(UInt8(type.rawValue))
    return data
  }
}

struct MessageHeaderType2: MessageHeader {
  let timestampDelta: TimeInterval
  
  func encode() -> Data {
    var data = Data()
    data.append(UInt32(timestampDelta).bigEndian.data)
    return data
  }
}
struct MessageHeaderType3: MessageHeader {
  func encode() -> Data {
      return Data()
  }
}
