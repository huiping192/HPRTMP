//
//  VideoMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

struct VideoMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .video }
  var streamId: UInt16 { RTMPChunkStreamId.video.rawValue }
  var payload: Data { data }
  var priority: MessagePriority { .low }
}
