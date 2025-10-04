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

class CommandMessage: RTMPBaseMessage, @unchecked Sendable, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String
  var commandNameType: CommandNameType? {
    CommandNameType(rawValue: commandName)
  }
  let transactionId: Int
  let commandObject: [String: Any]?

  let info: Any?
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .command(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }

  init(encodeType: ObjectEncodingType,
       commandName: String,
       msgStreamId: Int = 0,
       transactionId: Int,
       commandObject: [String: Any]? = nil,
       info: Any? = nil) {
    self.commandName = commandName
    self.transactionId = transactionId
    self.commandObject = commandObject
    self.info = info
    self.encodeType = encodeType
    self.msgStreamId = msgStreamId
    self.timestamp = 0
  }

  var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()

    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      data.append((encoder.encode(commandObject)) ?? Data())
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


final class ConnectMessage: CommandMessage, @unchecked Sendable {
  let argument: [String: Any]?
  init(encodeType: ObjectEncodingType = .amf0,
       tcUrl: String,
       appName: String,
       flashVer: String,
       swfURL: URL? = nil,
       fpad: Bool,
       audio: RTMPAudioCodecsType,
       video: RTMPVideoCodecsType,
       pageURL: URL? = nil,
       argument: [String: Any]? = nil) {
    self.argument = argument
    let obj:[String: Any] = ["app": appName,
                              "flashver": flashVer,
                              "swfUrl":swfURL?.absoluteString ?? "",
                              "tcUrl":tcUrl,
                              "fpad":fpad,
                              "audioCodecs": audio.rawValue,
                              "videoCodecs":video.rawValue,
                              "videoFunction":RTMPVideoFunction.seek.rawValue,
                              "pageUrl":pageURL?.absoluteString ?? "",
                              "objectEncoding":encodeType.rawValue]
    
    super.init(encodeType: encodeType, commandName: "connect", transactionId: commonTransactionId.connect, commandObject: obj)
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


final class CreateStreamMessage: CommandMessage, @unchecked Sendable {
  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: Any]? = nil) {
    super.init(encodeType: encodeType,commandName: "createStream", transactionId: transactionId, commandObject: commonObject)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      data.append((encoder.encode(commandObject)) ?? Data())
    } else {
      data.append(encoder.encodeNil())
    }

    return data
  }
  
  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CreateStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

final class CloseStreamMessage: CommandMessage, @unchecked Sendable {
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    super.init(encodeType: encodeType,commandName: "closeStream", msgStreamId: msgStreamId, transactionId: 0, commandObject: nil)
  }
  
  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CloseStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

final class DeleteStreamMessage: CommandMessage, @unchecked Sendable {
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    super.init(encodeType: encodeType,commandName: "deleteStream", msgStreamId: msgStreamId, transactionId: 0, commandObject: nil)
  }
  
  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "DeleteStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

public enum PubishType: String {
  case live = "live"
  case record = "record"
  case append = "append"
}

final class PublishMessage: CommandMessage, @unchecked Sendable {
  let type: PubishType
  let streamName: String
  init(encodeType: ObjectEncodingType = .amf0, streamName: String, type: PubishType, msgStreamId: Int = 0) {
    self.streamName = streamName
    self.type = type
    super.init(encodeType: encodeType, commandName: "publish", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }
  
  override var payload: Data {
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


final class SeekMessage: CommandMessage, @unchecked Sendable {
  let millSecond: Double
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int, millSecond: Double) {
    self.millSecond = millSecond
    super.init(encodeType: encodeType, commandName: "seek", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((encoder.encode(commandName)) ?? Data())
    data.append((encoder.encode(Double(transactionId))) ?? Data())
    data.append((encoder.encodeNil()))
    data.append((encoder.encode(millSecond)) ?? Data())

    return data
  }
}


final class PauseMessage: CommandMessage, @unchecked Sendable {
  let isPause: Bool
  let millSecond: Double
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId:Int, isPause: Bool, millSecond: Double) {
    self.isPause = isPause
    self.millSecond = millSecond
    super.init(encodeType: encodeType, commandName: "pause", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }
  
  override var payload: Data {
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

