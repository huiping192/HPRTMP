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

class UserControlMessage: RTMPBaseMessage, Encodable {
  let type: UserControlEventType
  let data: Data
  
  init(type: UserControlEventType, data: Data, streamId: Int) {
    self.type = type
    self.data = data
    
    super.init(type: .control, streamId: streamId)
  }
  
  convenience init(streamBufferLength: Int, streamId: Int) {
    var data = Data()
    let id = UInt32(streamId).bigEndian.data
    data.append(id)
    let length = UInt32(streamBufferLength).bigEndian.data
    data.append(length)

    self.init(type: .streamBufferLength, data: data, streamId: streamId)
  }
  
  func encode() -> Data {
    var data = Data()
    data.write(UInt16(type.rawValue))
    data.append(data)
    return data
  }
  
  
}
