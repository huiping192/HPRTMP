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
    data.append(UInt32(time).bigEndian.data)
    data.append(UInt32(messageLength).bigEndian.data)
    data.append(type.rawValue)
    data.append(UInt32(messageStreamId).data)

    if isExtendTime {
      data.append(UInt32(Int(timestamp)).bigEndian.data)
    }
    return data
  }
  
  static func == (lhs: MessageHeaderType0, rhs: MessageHeaderType0) -> Bool {
    return lhs.timestamp == rhs.timestamp && lhs.messageLength == rhs.messageLength && lhs.type == rhs.type && lhs.messageStreamId == rhs.messageStreamId
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
  
  static func == (lhs: MessageHeaderType1, rhs: MessageHeaderType1) -> Bool {
    return lhs.timestampDelta == rhs.timestampDelta && lhs.messageLength == rhs.messageLength && lhs.type == rhs.type
  }
}

struct MessageHeaderType2: MessageHeader {
  let timestampDelta: TimeInterval
  
  func encode() -> Data {
    var data = Data()
    data.append(UInt32(timestampDelta).bigEndian.data)
    return data
  }
  
  static func == (lhs: MessageHeaderType2, rhs: MessageHeaderType2) -> Bool {
    return lhs.timestampDelta == rhs.timestampDelta
  }
}
struct MessageHeaderType3: MessageHeader {
  func encode() -> Data {
      return Data()
  }
  
  static func == (lhs: MessageHeaderType3, rhs: MessageHeaderType3) -> Bool {
    true
  }
}
