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
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)

    if let commandObject {
      let objectValue = AMFValue.object(commandObject)
      data.append(encodeType == .amf0 ? objectValue.amf0Value : objectValue.amf3Value)
    }

    if let info {
      data.append(encodeType == .amf0 ? info.amf0Value : info.amf3Value)
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
  let msgStreamId: MessageStreamId = .zero
  let timestamp: Timestamp = .zero
  let argument: [String: AMFValue]?

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

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

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)

    if let commandObject {
      let objectValue = AMFValue.object(commandObject)
      data.append(encodeType == .amf0 ? objectValue.amf0Value : objectValue.amf3Value)
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
  let msgStreamId: MessageStreamId = .zero
  let timestamp: Timestamp = .zero

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: AMFValue]? = nil) {
    self.encodeType = encodeType
    self.transactionId = transactionId
    self.commandObject = commonObject
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)

    if let commandObject {
      let objectValue = AMFValue.object(commandObject)
      data.append(encodeType == .amf0 ? objectValue.amf0Value : objectValue.amf3Value)
    } else {
      let nullValue = AMFValue.null
      data.append(encodeType == .amf0 ? nullValue.amf0Value : nullValue.amf3Value)
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
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: MessageStreamId) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)

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
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: MessageStreamId) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)

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
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero
  let type: PubishType
  let streamName: String

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, streamName: String, type: PubishType, msgStreamId: MessageStreamId = .zero) {
    self.encodeType = encodeType
    self.streamName = streamName
    self.type = type
    self.msgStreamId = msgStreamId
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))
    let nullValue = AMFValue.null
    let streamNameValue = AMFValue.string(streamName)
    let typeValue = AMFValue.string(self.type.rawValue)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)
    data.append(encodeType == .amf0 ? nullValue.amf0Value : nullValue.amf3Value)
    data.append(encodeType == .amf0 ? streamNameValue.amf0Value : streamNameValue.amf3Value)
    data.append(encodeType == .amf0 ? typeValue.amf0Value : typeValue.amf3Value)

    return data
  }
}


struct SeekMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "seek"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero
  let millSecond: Double

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: MessageStreamId, millSecond: Double) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.millSecond = millSecond
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))
    let nullValue = AMFValue.null
    let millSecondValue = AMFValue.double(millSecond)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)
    data.append(encodeType == .amf0 ? nullValue.amf0Value : nullValue.amf3Value)
    data.append(encodeType == .amf0 ? millSecondValue.amf0Value : millSecondValue.amf3Value)

    return data
  }
}


struct PauseMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "pause"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero
  let isPause: Bool
  let millSecond: Double

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: MessageStreamId, isPause: Bool, millSecond: Double) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.isPause = isPause
    self.millSecond = millSecond
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))
    let nullValue = AMFValue.null
    let isPauseValue = AMFValue.bool(isPause)
    let millSecondValue = AMFValue.double(millSecond)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)
    data.append(encodeType == .amf0 ? nullValue.amf0Value : nullValue.amf3Value)
    data.append(encodeType == .amf0 ? isPauseValue.amf0Value : isPauseValue.amf3Value)
    data.append(encodeType == .amf0 ? millSecondValue.amf0Value : millSecondValue.amf3Value)

    return data
  }
}

struct PlayMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String = "play"
  let transactionId: Int = commonTransactionId.stream
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp = .zero
  let streamName: String
  let start: Double
  let duration: Double
  let reset: Bool

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }

  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: MessageStreamId, streamName: String, start: Double = -1, duration: Double = -1, reset: Bool = false) {
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.streamName = streamName
    self.start = start
    self.duration = duration
    self.reset = reset
  }

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string(commandName)
    let transactionIdValue = AMFValue.double(Double(transactionId))
    let nullValue = AMFValue.null
    let streamNameValue = AMFValue.string(streamName)
    let startValue = AMFValue.double(start)
    let durationValue = AMFValue.double(duration)
    let resetValue = AMFValue.bool(reset)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? transactionIdValue.amf0Value : transactionIdValue.amf3Value)
    data.append(encodeType == .amf0 ? nullValue.amf0Value : nullValue.amf3Value)
    data.append(encodeType == .amf0 ? streamNameValue.amf0Value : streamNameValue.amf3Value)
    data.append(encodeType == .amf0 ? startValue.amf0Value : startValue.amf3Value)
    data.append(encodeType == .amf0 ? durationValue.amf0Value : durationValue.amf3Value)
    data.append(encodeType == .amf0 ? resetValue.amf0Value : resetValue.amf3Value)

    return data
  }
}
