//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation

let commonTransactionId = (connect: 1, stream: 0)

enum CodeType {
  enum Call: String {
    case badVersion = "NetConnection.Call.BadVersion"
    case failed     = "NetConnection.Call.Failed"
  }
  
  enum Connect: String, Decodable {
    case failed         = "NetConnection.Connect.Failed"
    case timeout        = "NetConnection.Connect.IdleTimeOut"
    case invalidApp     = "NetConnection.Connect.InvalidApp"
    case networkChange  = "NetConnection.Connect.NetworkChange"
    case reject         = "NetConnection.Connect.Rejected"
    case success        = "NetConnection.Connect.Success"
  }
}

enum CommandNameType: String {
  //检测带宽成功
  case onBWDone     = "onBWDone"
  case onStatus     = "onStatus"
  case onMetaData = "onMetaData"
  case publish     = "publish"
  case result     = "_result"
  case error     = "_error"
}

struct CommandMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String
  var commandNameType: CommandNameType? {
    CommandNameType(rawValue: commandName)
  }
  let transactionId: Int
  let commandObject: [String: AMFValue]?

  let info: AMFValue?
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      let anyDict = commandObject.mapValues { $0.toAny() }
      data.append((encoder.encode(anyDict)) ?? Data())
    }

    return data
  }

  var description: String {
      var result = ""
      result += "Command Name: \(commandName)\n"
      result += "Transaction ID: \(transactionId)\n"
      if let object = commandObject {
        result += "Command Object: \(object)\n"
      }
      if let info = info {
        result += "Info: \(info)\n"
      }
      return result
    }
}


struct ConnectMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String = "connect"
  let transactionId: Int = commonTransactionId.connect
  let commandObject: [String: AMFValue]?
  let msgStreamId: Int = 0
  let timestamp: UInt32 = 0
  let argument: [String: AMFValue]?

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0,
       tcUrl: String,
       appName: String,
       flashVer: String,
       swfURL: URL? = nil,
       fpad: Bool,
       audio: RTMPAudioCodecsType,
       video: RTMPVideoCodecsType,
       pageURL: URL? = nil,
       argument: [String: AMFValue]? = nil) {
    self.encodeType = encodeType
    self.argument = argument
    let obj: [String: AMFValue] = [
      "app": .string(appName),
      "flashver": .string(flashVer),
      "swfUrl": .string(swfURL?.absoluteString ?? ""),
      "tcUrl": .string(tcUrl),
      "fpad": .bool(fpad),
      "audioCodecs": .double(Double(audio.rawValue)),
      "videoCodecs": .double(Double(video.rawValue)),
      "videoFunction": .double(Double(RTMPVideoFunction.seek.rawValue)),
      "pageUrl": .string(pageURL?.absoluteString ?? ""),
      "objectEncoding": .double(Double(encodeType.rawValue))
    ]
    self.commandObject = obj
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      let anyDict = commandObject.mapValues { $0.toAny() }
      data.append((encoder.encode(anyDict)) ?? Data())
    }
    return data
  }

  var description: String {
      var desc = "ConnectMessage("
      desc += "commandName: \(commandName), "
      desc += "transactionId: \(transactionId), "
      desc += "commandObject: \(String(describing: commandObject)), "
      desc += "argument: \(String(describing: argument))"
      desc += ")"
      return desc
    }
}


struct CreateStreamMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String = "createStream"
  let transactionId: Int
  let commandObject: [String: AMFValue]?
  let msgStreamId: Int = 0
  let timestamp: UInt32 = 0

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: AMFValue]? = nil) {
    self.encodeType = encodeType
    self.transactionId = transactionId
    self.commandObject = commonObject
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      let anyDict = commandObject.mapValues { $0.toAny() }
      data.append((encoder.encode(anyDict)) ?? Data())
    } else {
      data.append(encoder.encodeNil())
    }

    return data
  }

  var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    return "CreateStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc) }"
  }
}

struct CloseStreamMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String = "closeStream"
  let transactionId: Int = 0
  let msgStreamId: Int
  let timestamp: UInt32 = 0

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    return data
  }

  var description: String {
    return "CloseStreamMessage: { commandName: \(commandName), transactionId: \(transactionId) }"
  }
}

struct DeleteStreamMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String = "deleteStream"
  let transactionId: Int = 0
  let msgStreamId: Int
  let timestamp: UInt32 = 0

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    return data
  }

  var description: String {
    return "DeleteStreamMessage: { commandName: \(commandName), transactionId: \(transactionId) }"
  }
}

public enum PubishType: String, Sendable {
  case live = "live"
  case record = "record"
  case append = "append"
}

struct PublishMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "publish"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: Int
  let timestamp: UInt32 = 0
  let type: PubishType
  let streamName: String

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, streamName: String, type: PubishType, msgStreamId: Int = 0) {
    self.encodeType = encodeType
    self.streamName = streamName
    self.type = type
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    data.append((encoder.encodeNil()))
    data.append((encoder.encode(streamName)) ?? Data())
    data.append((encoder.encode(self.type.rawValue)) ?? Data())

    return data
  }
}


struct SeekMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "seek"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: Int
  let timestamp: UInt32 = 0
  let millSecond: Double

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int, millSecond: Double) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.millSecond = millSecond
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    data.append((encoder.encodeNil()))
    data.append((encoder.encode(millSecond)) ?? Data())

    return data
  }
}


struct PauseMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "pause"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: Int
  let timestamp: UInt32 = 0
  let isPause: Bool
  let millSecond: Double

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId:Int, isPause: Bool, millSecond: Double) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.isPause = isPause
    self.millSecond = millSecond
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    data.append((encoder.encodeNil()))
    data.append((encoder.encode(isPause)) ?? Data())
    data.append((encoder.encode(millSecond)) ?? Data())

    return data
  }
}

