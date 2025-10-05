//
//  DataMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

protocol DataMessage: RTMPBaseMessage {
  var encodeType: ObjectEncodingType { get }
  var msgStreamId: MessageStreamId { get }
  var timestamp: Timestamp { get }
}

extension DataMessage {
  var messageType: MessageType { .data(type: encodeType) }
  var streamId: ChunkStreamId { RTMPChunkStreamId.command.chunkStreamId }
  var timestamp: Timestamp { .zero }
}

struct AnyDataMessage: DataMessage, Sendable {
  let encodeType: ObjectEncodingType
  let msgStreamId: MessageStreamId

  var payload: Data {
    Data()
  }
}
