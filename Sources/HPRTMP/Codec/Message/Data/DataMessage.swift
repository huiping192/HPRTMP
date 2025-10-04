//
//  DataMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

protocol DataMessage: RTMPBaseMessage {
  var encodeType: ObjectEncodingType { get }
  var msgStreamId: Int { get }
  var timestamp: UInt32 { get }
}

extension DataMessage {
  var messageType: MessageType { .data(type: encodeType) }
  var streamId: UInt16 { RTMPChunkStreamId.command.rawValue }
  var timestamp: UInt32 { 0 }
}

struct AnyDataMessage: DataMessage, Sendable {
  let encodeType: ObjectEncodingType
  let msgStreamId: Int

  var payload: Data {
    Data()
  }
}
