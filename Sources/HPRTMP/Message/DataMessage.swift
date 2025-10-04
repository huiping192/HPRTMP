//
//  DataMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//


import Foundation

// max timestamp 0xFFFFFF
let maxTimestamp: UInt32 = 16777215

enum RTMPChunkStreamId: UInt16 {
  case control = 2
  case command = 3
  case audio = 4
  case video = 5
}

public protocol RTMPMessage: Sendable {
  var timestamp: UInt32 { get }
  var messageType: MessageType { get }
  var msgStreamId: Int  { get }
  var streamId: UInt16  { get }

  var payload: Data { get}

  var priority: MessagePriority { get }
}

public extension RTMPMessage {
  var priority: MessagePriority {
    .high
  }
}

public protocol RTMPBaseMessage: RTMPMessage {
  var messageType: MessageType { get }
  var msgStreamId: Int { get }
  var streamId: UInt16 { get }
  var timestamp: UInt32 { get }
}


protocol DataMessage: RTMPBaseMessage {
  var encodeType: ObjectEncodingType { get }
  var msgStreamId: Int { get }
  var timestamp: UInt32 { get }
}

extension DataMessage {
  var messageType: MessageType { .data(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }
  var timestamp: UInt32 { 0 }
}

struct AnyDataMessage: DataMessage, Sendable {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int
  
  var payload: Data {
    Data()
  }
}

final class MetaMessage: DataMessage, @unchecked Sendable {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int
  
  let meta: [String: Any]
  init(encodeType: ObjectEncodingType, msgStreamId: Int, meta: [String: Any]) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.meta = meta
  }
  
  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode("onMetaData")) ?? Data())
    data.append((encoder.encode(meta)) ?? Data())
    
    return data
  }
}

struct VideoMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .video }
  var streamId: UInt16 { RTMPChunkStreamId.video.rawValue }
  var payload: Data { data }
  var priority: MessagePriority { .low }
}


struct AudioMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .audio }
  var streamId: UInt16 { RTMPChunkStreamId.audio.rawValue }
  var payload: Data { data }
  var priority: MessagePriority { .medium }
}

final class SharedObjectMessage: DataMessage, @unchecked Sendable {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int
  
  let sharedObjectName: String?
  let sharedObject: [String: Any]?
  
  init(encodeType: ObjectEncodingType, msgStreamId: Int, sharedObjectName: String?, sharedObject: [String: Any]?) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.sharedObjectName = sharedObjectName
    self.sharedObject = sharedObject
  }
  
  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode("onSharedObject")) ?? Data())
    if let sharedObjectName {
      data.append((encoder.encode(sharedObjectName)) ?? Data())
    }
    if let sharedObject {
      data.append((encoder.encode(sharedObject)) ?? Data())
    }
    return data
  }
}
