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
  // 检测带宽成功
  case onBWDone     = "onBWDone"
  case onStatus     = "onStatus"
  case onMetaData = "onMetaData"
  case publish     = "publish"
  case result     = "_result"
  case error     = "_error"
}

class CommandMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String
  var commandNameType: CommandNameType? {
    CommandNameType(rawValue: commandName)
  }
  let transactionId: Int
  let commandObject: [String: Any?]?

  let info: Any?

  init(encodeType: ObjectEncodingType,
       commandName: String,
       msgStreamId: Int = 0,
       transactionId: Int,
       commandObject: [String: Any?]? = nil,
       info: Any? = nil) {
    self.commandName = commandName
    self.transactionId = transactionId
    self.commandObject = commandObject
    self.info = info
    self.encodeType = encodeType
    super.init(type: .command(type: encodeType), msgStreamId: msgStreamId, streamId: RTMPStreamId.command.rawValue)
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

class ConnectMessage: CommandMessage, Encodable {
  let argument: [String: Any?]?
  init(encodeType: ObjectEncodingType = .amf0,
       tcUrl: String,
       appName: String,
       flashVer: String,
       swfURL: URL? = nil,
       fpad: Bool,
       audio: RTMPAudioCodecsType,
       video: RTMPVideoCodecsType,
       pageURL: URL? = nil,
       argument: [String: Any?]? = nil) {
    self.argument = argument
    let obj: [String: Any?] = ["app": appName,
                              "flashver": flashVer,
                              "swfUrl": swfURL?.absoluteString,
                              "tcUrl": tcUrl,
                              "fpad": fpad,
                              "audioCodecs": audio.rawValue,
                              "videoCodecs": video.rawValue,
                              "videoFunction": RTMPVideoFunction.seek.rawValue,
                              "pageUrl": pageURL?.absoluteString,
                              "objectEncoding": encodeType.rawValue]

    super.init(encodeType: encodeType, commandName: "connect", transactionId: commonTransactionId.connect, commandObject: obj)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }

  override var description: String {
      var desc = "ConnectMessage("
      desc += "commandName: \(commandName), "
      desc += "transactionId: \(transactionId), "
      desc += "commandObject: \(String(describing: commandObject)), "
      desc += "argument: \(String(describing: argument))"
      desc += ")"
      return desc
    }
}

class CreateStreamMessage: CommandMessage, Encodable {
  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: Any?]? = nil) {
    super.init(encodeType: encodeType, commandName: "createStream", transactionId: transactionId, commandObject: commonObject)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }

  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CreateStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

class CloseStreamMessage: CommandMessage, Encodable {
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    super.init(encodeType: encodeType, commandName: "closeStream", msgStreamId: msgStreamId, transactionId: 0, commandObject: nil)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }

  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CloseStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

class DeleteStreamMessage: CommandMessage, Encodable {
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    super.init(encodeType: encodeType, commandName: "deleteStream", msgStreamId: msgStreamId, transactionId: 0, commandObject: nil)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }

  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "DeleteStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

public enum PubishType: String {
  case live
  case record
  case append
}

class PublishMessage: CommandMessage, Encodable {
  let type: PubishType
  let streamName: String
  init(encodeType: ObjectEncodingType = .amf0, streamName: String, type: PubishType) {
    self.streamName = streamName
    self.type = type
    super.init(encodeType: encodeType, commandName: "publish", transactionId: commonTransactionId.stream)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.appendNil()
    amf.append(streamName)
    amf.append(self.type.rawValue)
    return amf.data
  }
}

class SeekMessage: CommandMessage, Encodable {
  let millSecond: Double
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int, millSecond: Double) {
    self.millSecond = millSecond
    super.init(encodeType: encodeType, commandName: "seek", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.appendNil()
    amf.append(millSecond)
    return amf.data
  }
}

class PauseMessage: CommandMessage, Encodable {
  let isPause: Bool
  let millSecond: Double
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int, isPause: Bool, millSecond: Double) {
    self.isPause = isPause
    self.millSecond = millSecond
    super.init(encodeType: encodeType, commandName: "pause", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }

  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.appendNil()
    amf.appned(isPause)
    amf.append(millSecond)
    return amf.data
  }
}
