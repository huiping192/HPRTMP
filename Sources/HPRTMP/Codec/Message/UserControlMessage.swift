//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation

enum UserControlEventType: Int {
    case streamBegin = 0
    case streamEOF = 1
    case streamDry = 2
    case streamBufferLength = 3
    case streamIsRecorded = 4
    case pingRequest = 6
    case pingResponse = 7
    case none = 0xff
}

struct UserControlMessage: RTMPBaseMessage {
  let type: UserControlEventType
  let data: Data
  let streamId: UInt16

  var msgStreamId: Int { 0 }
  var timestamp: UInt32 { 0 }
  var messageType: MessageType { .control }
  var payload: Data {
    var data = Data()
    data.write(UInt16(type.rawValue))
    data.append(self.data)
    return data
  }

  init(type: UserControlEventType, data: Data, streamId: UInt16) {
    self.type = type
    self.data = data
    self.streamId = streamId
  }

  init(streamBufferLength: Int, streamId: UInt16) {
    var data = Data()
    let id = UInt32(streamId).bigEndian.data
    data.append(id)
    let length = UInt32(streamBufferLength).bigEndian.data
    data.append(length)

    self.init(type: .streamBufferLength, data: data, streamId: streamId)
  }
}
