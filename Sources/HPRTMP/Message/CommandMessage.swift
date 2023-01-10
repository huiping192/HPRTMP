//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation

let commonTransactionId = (connect: 1, stream: 0)

class CommandMessage: RTMPBaseMessage {
  let encodeType: ObjectEncodingType
  let commandName: String
  let transactionId: Int
  let commandObject: [String: Any?]?
  
  init(encodeType: ObjectEncodingType,
       commandName: String,
       msgStreamId: Int = 0,
       transactionId: Int,
       commandObject: [String: Any?]? = nil) {
    self.commandName = commandName
    self.transactionId = transactionId
    self.commandObject = commandObject
    self.encodeType = encodeType
    super.init(type: .command(type: encodeType),msgStreamId: msgStreamId, streamId: RTMPStreamId.command.rawValue)
  }
}


class ConnectMessage: CommandMessage, Encodable {
  let argument: [String: Any?]?
  init(encodeType: ObjectEncodingType = .amf0,
       url: URL,
       flashVer: String,
       swfURL: URL? = nil,
       fpad: Bool,
       audio: RTMPAudioCodecsType,
       video: RTMPVideoCodecsType,
       pageURL: URL? = nil,
       argument: [String: Any?]? = nil) {
    self.argument = argument
    let u = url.path.split(separator: "/").first ?? "urlEmpty"
    let obj:[String: Any?] = ["app": String(u),
                              "flashver": flashVer,
                              "swfUrl":swfURL?.absoluteString,
                              "tcUrl":url.absoluteString,
                              "fpad":fpad,
                              "audioCodecs": audio.rawValue,
                              "videoCodecs":video.rawValue,
                              "videoFunction":RTMPVideoFunction.seek.rawValue,
                              "pageUrl":pageURL?.absoluteString,
                              "objectEncoding":encodeType.rawValue]
    
    super.init(encodeType: encodeType, commandName: "connect", transactionId: commonTransactionId.connect, commandObject: obj)
  }
  
  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }
}


class CreateStreamMessage: CommandMessage, Encodable {
  init(encodeType: ObjectEncodingType = .amf0, transactionId: Int, commonObject: [String: Any?]? = nil) {
    super.init(encodeType: encodeType,commandName: "createStream", transactionId: transactionId, commandObject: commonObject)
  }
  
  func encode() -> Data {
    var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
    amf.append(commandName)
    amf.append(Double(transactionId))
    amf.append(commandObject)
    return amf.data
  }
}

public enum PubishType: String {
  case live = "live"
  case record = "record"
  case append = "append"
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
  init(encodeType: ObjectEncodingType = .amf0, msgStreamId:Int, isPause: Bool, millSecond: Double) {
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

