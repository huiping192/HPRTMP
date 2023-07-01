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

class CommandMessage: RTMPBaseMessage, CustomStringConvertible {
  let encodeType: ObjectEncodingType
  let commandName: String
  var commandNameType: CommandNameType? {
    CommandNameType(rawValue: commandName)
  }
  let transactionId: Int
  let commandObject: [String: Any]?
  
  let info: Any?

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
    super.init(type: .command(type: encodeType),msgStreamId: msgStreamId, streamId: RTMPStreamId.command.rawValue)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((try? encoder.encode(commandName)) ?? Data())
    data.append((try? encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      data.append((try? encoder.encode(commandObject)) ?? Data())
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


class ConnectMessage: CommandMessage {
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


class CreateStreamMessage: CommandMessage {
  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: Any]? = nil) {
    super.init(encodeType: encodeType,commandName: "createStream", transactionId: transactionId, commandObject: commonObject)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((try? encoder.encode(commandName)) ?? Data())
    data.append((try? encoder.encode(Double(transactionId))) ?? Data())
    if let commandObject {
      data.append((try? encoder.encode(commandObject)) ?? Data())
    }

    return data
  }
  
  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CreateStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

class CloseStreamMessage: CommandMessage {
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int) {
    super.init(encodeType: encodeType,commandName: "closeStream", msgStreamId: msgStreamId, transactionId: 0, commandObject: nil)
  }
  
  override var description: String {
    let objDesc = commandObject != nil ? "\(commandObject!)" : "nil"
    let infoDesc = info != nil ? "\(info!)" : "nil"
    return "CloseStreamMessage: { commandName: \(commandName), transactionId: \(transactionId), commandObject: \(objDesc), info: \(infoDesc) }"
  }
}

class DeleteStreamMessage: CommandMessage {
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

class PublishMessage: CommandMessage {
  let type: PubishType
  let streamName: String
  init(encodeType: ObjectEncodingType = .amf0, streamName: String, type: PubishType) {
    self.streamName = streamName
    self.type = type
    super.init(encodeType: encodeType, commandName: "publish", transactionId: commonTransactionId.stream)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((try? encoder.encode(commandName)) ?? Data())
    data.append((try? encoder.encode(Double(transactionId))) ?? Data())
    data.append((try? encoder.encodeNil()) ?? Data())
    data.append((try? encoder.encode(streamName)) ?? Data())
    data.append((try? encoder.encode(self.type.rawValue)) ?? Data())

    return data
  }
}


class SeekMessage: CommandMessage {
  let millSecond: Double
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId: Int, millSecond: Double) {
    self.millSecond = millSecond
    super.init(encodeType: encodeType, commandName: "seek", msgStreamId: msgStreamId, transactionId: commonTransactionId.stream)
  }
  
  override var payload: Data {
    var data = Data()
    let encoder = AMF0Encoder()
    
    data.append((try? encoder.encode(commandName)) ?? Data())
    data.append((try? encoder.encode(Double(transactionId))) ?? Data())
    data.append((try? encoder.encodeNil()) ?? Data())
    data.append((try? encoder.encode(millSecond)) ?? Data())

    return data
  }
}


class PauseMessage: CommandMessage {
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
    
    data.append((try? encoder.encode(commandName)) ?? Data())
    data.append((try? encoder.encode(Double(transactionId))) ?? Data())
    data.append((try? encoder.encodeNil()) ?? Data())
    data.append((try? encoder.encode(isPause)) ?? Data())
    data.append((try? encoder.encode(millSecond)) ?? Data())

    return data
  }
}

