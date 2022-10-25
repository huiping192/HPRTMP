//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/25.
//

import Foundation

protocol MessageHeader {
  func encode() -> Data
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
    let time = timestamp > maxTimestamp ?  maxTimestamp : timestamp
    data.append(UInt32(time).bigEndian.data)
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
