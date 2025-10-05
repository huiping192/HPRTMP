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
  let streamId: ChunkStreamId

  var msgStreamId: MessageStreamId { .zero }
  var timestamp: Timestamp { .zero }
  var messageType: MessageType { .control }
  var payload: Data {
    var data = Data()
    data.write(UInt16(type.rawValue))
    data.append(self.data)
    return data
  }

  init(type: UserControlEventType, data: Data, streamId: ChunkStreamId) {
    self.type = type
    self.data = data
    self.streamId = streamId
  }

  init(streamBufferLength: Int, streamId: ChunkStreamId) {
    var data = Data()
    let id = UInt32(streamId.value).bigEndian.data
    data.append(id)
    let length = UInt32(streamBufferLength).bigEndian.data
    data.append(length)

    self.init(type: .streamBufferLength, data: data, streamId: streamId)
  }
}
