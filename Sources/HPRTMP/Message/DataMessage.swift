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

public struct MetaData: Sendable {
  let width: Int32
  let height: Int32
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  let videodatarate: Int?
  let audiodatarate: Int?
  let audiosamplerate: Int?

  var dictionary: [String: Any] {
    var dic: [String: Any] = [
      "width": width,
      "height": height,
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate
    ]
    if let videodatarate {
      dic["videodatarate"] = videodatarate
    }
    if let audiodatarate {
      dic["audiodatarate"] = audiodatarate
    }
    if let audiosamplerate {
      dic["audiosamplerate"] = audiosamplerate
    }
    return dic
  }
}

struct MetaMessage: DataMessage {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int
  let meta: MetaData

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string("onMetaData")

    // Convert meta.dictionary to [String: AMFValue]
    var metaDict: [String: AMFValue] = [
      "width": .double(Double(meta.width)),
      "height": .double(Double(meta.height)),
      "videocodecid": .double(Double(meta.videocodecid)),
      "audiocodecid": .double(Double(meta.audiocodecid)),
      "framerate": .double(Double(meta.framerate))
    ]
    if let videodatarate = meta.videodatarate {
      metaDict["videodatarate"] = .double(Double(videodatarate))
    }
    if let audiodatarate = meta.audiodatarate {
      metaDict["audiodatarate"] = .double(Double(audiodatarate))
    }
    if let audiosamplerate = meta.audiosamplerate {
      metaDict["audiosamplerate"] = .double(Double(audiosamplerate))
    }

    let metaValue = AMFValue.object(metaDict)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? metaValue.amf0Value : metaValue.amf3Value)

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

struct SharedObjectMessage: DataMessage {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int

  let sharedObjectName: String?
  let sharedObject: [String: AMFValue]?

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string("onSharedObject")
    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)

    if let sharedObjectName {
      let nameValue = AMFValue.string(sharedObjectName)
      data.append(encodeType == .amf0 ? nameValue.amf0Value : nameValue.amf3Value)
    }

    if let sharedObject {
      let objectValue = AMFValue.object(sharedObject)
      data.append(encodeType == .amf0 ? objectValue.amf0Value : objectValue.amf3Value)
    }

    return data
  }
}
