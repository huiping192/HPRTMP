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

protocol RTMPMessage {
  var timestamp: UInt32 { set get }
  var messageType: MessageType { get }
  var msgStreamId: Int  { get set }
  var streamId: UInt16  { get }
  
  var payload: Data { get}
  
  var priority: MessagePriority { get }
}

extension RTMPMessage {
  var priority: MessagePriority {
    .high
  }
}

public class RTMPBaseMessage: RTMPMessage {
  let messageType: MessageType
  var msgStreamId: Int
  let streamId: UInt16
  
  var payload: Data {
    Data()
  }
  
  init(type: MessageType, msgStreamId: Int = 0, streamId: UInt16) {
    self.messageType = type
    self.msgStreamId = msgStreamId
    self.streamId = streamId
  }
  
  private var _timeInterval: UInt32 = 0
  public var timestamp:UInt32  {
    set {
      _timeInterval = newValue >= maxTimestamp ? maxTimestamp : newValue
    } get {
      return _timeInterval
    }
  }
}


class DataMessage: RTMPBaseMessage {
  var encodeType: ObjectEncodingType
  init(encodeType: ObjectEncodingType, msgStreamId: Int) {
    self.encodeType = encodeType
    super.init(type: .data(type: encodeType),
               msgStreamId: msgStreamId,
               streamId: RTMPChunkStreamId.command.rawValue)
  }
}

class MetaMessage: DataMessage {
  let meta: [String: Any]
  init(encodeType: ObjectEncodingType, msgStreamId: Int, meta: [String: Any]) {
    self.meta = meta
    super.init(encodeType: encodeType,
               msgStreamId: msgStreamId)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode("onMetaData")) ?? Data())
    data.append((encoder.encode(meta)) ?? Data())
    
    return data
  }
}


class VideoMessage: RTMPBaseMessage {
  let data: Data
  init(msgStreamId: Int, data: Data, timestamp: UInt32) {
    self.data = data
    super.init(type: .video,
               msgStreamId: msgStreamId,
               streamId: RTMPChunkStreamId.video.rawValue)
    self.timestamp = timestamp
  }
  override var payload: Data {
    return data
  }
  
  var priority: MessagePriority {
    .low
  }
}


class AudioMessage: RTMPBaseMessage {
  let data: Data
  
  init(msgStreamId: Int, data: Data, timestamp: UInt32) {
    self.data = data
    super.init(type: .audio,
               msgStreamId: msgStreamId,
               streamId: RTMPChunkStreamId.audio.rawValue)
    self.timestamp = timestamp
  }
  override var payload: Data {
    return data
  }
  
  var priority: MessagePriority {
    .medium
  }
}

class SharedObjectMessage: DataMessage {
  let sharedObjectName: String?
  let sharedObject: [String: Any]?
  
  init(encodeType: ObjectEncodingType, msgStreamId: Int, sharedObjectName: String?, sharedObject: [String: Any]?) {
    self.sharedObjectName = sharedObjectName
    self.sharedObject = sharedObject
    super.init(encodeType: encodeType, msgStreamId: msgStreamId)
  }
  
  override var payload: Data {
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
