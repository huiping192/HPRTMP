//
//  AudioMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

struct AudioMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp

  var messageType: MessageType { .audio }
  var streamId: ChunkStreamId { RTMPChunkStreamId.audio.chunkStreamId }
  var payload: Data { data }
  var priority: MessagePriority { .medium }
}
