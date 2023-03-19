//
//  DataMessage.swift
//  
//
//  Created by Huiping Guo on 2022/11/03.
//


import Foundation

// max timestamp 0xFFFFFF
let maxTimestamp: UInt32 = 16777215


enum RTMPStreamId: Int {
    case control = 2
    case command = 3
    case audio = 4
    case video = 5
}

protocol RTMPBaseMessageProtocol {
    var timestamp: UInt32 { set get }
    var messageType: MessageType { get }
    var msgStreamId: Int  { get set }
    var streamId: Int  { get }
}

public class RTMPBaseMessage: RTMPBaseMessageProtocol {
    let messageType: MessageType
    var msgStreamId: Int
    let streamId: Int
    
    init(type: MessageType, msgStreamId: Int = 0, streamId: Int) {
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
                   streamId: RTMPStreamId.command.rawValue)
    }
}


class MetaMessage: DataMessage, Encodable {
    let meta: [String: Any]
    init(encodeType: ObjectEncodingType, msgStreamId: Int, meta: [String: Any]) {
        self.meta = meta
        super.init(encodeType: encodeType,
                   msgStreamId: msgStreamId)
    }
    
    func encode() -> Data {
        var amf: AMFProtocol = encodeType == .amf0 ? AMF0Object() : AMF3Object()
        amf.append("onMetaData")
        amf.append(meta)
        return amf.data
    }
}


class VideoMessage: RTMPBaseMessage, Encodable {
    let data: Data
    init(msgStreamId: Int, data: Data, timestamp: UInt32) {
        self.data = data
        super.init(type: .video,
                   msgStreamId: msgStreamId,
                   streamId: RTMPStreamId.video.rawValue)
        self.timestamp = timestamp
    }
    func encode() -> Data {
        return data
    }
}


class AudioMessage: RTMPBaseMessage, Encodable {
    let data: Data

    init(msgStreamId: Int, data: Data, timestamp: UInt32) {
        self.data = data
        super.init(type: .audio,
                   msgStreamId: msgStreamId,
                   streamId: RTMPStreamId.audio.rawValue)
        self.timestamp = timestamp
    }
    func encode() -> Data {
        return data
    }
}
