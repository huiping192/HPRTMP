//
//  VideoMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

struct VideoMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: MessageStreamId
  let timestamp: Timestamp

  var messageType: MessageType { .video }
  var streamId: ChunkStreamId { RTMPChunkStreamId.video.chunkStreamId }
  var payload: Data { data }
  var priority: MessagePriority { .low }
}
