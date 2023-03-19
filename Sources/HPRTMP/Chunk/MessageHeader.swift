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
  let maxTimestamp: UInt32 = 16777215
  
  let timestamp: UInt32
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
    data.append(UInt32(messageStreamId).bigEndian.data)

    if isExtendTime {
      data.append(timestamp.bigEndian.data)
    }
    return data
  }
}

struct MessageHeaderType1: MessageHeader {
  let timestampDelta: UInt32
  let messageLength: Int
  let type: MessageType
  
  func encode() -> Data {
    var data = Data()
    data.writeU24(Int(timestampDelta), bigEndian: true)
    data.writeU24(messageLength, bigEndian: true)
    data.write(type.rawValue)
    return data
  }
}

struct MessageHeaderType2: MessageHeader {
  let timestampDelta: UInt32
  
  func encode() -> Data {
    var data = Data()
    data.writeU24(Int(timestampDelta), bigEndian: true)
    return data
  }
}
struct MessageHeaderType3: MessageHeader {
  func encode() -> Data {
      return Data()
  }
}
