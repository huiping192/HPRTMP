//
//  AudioMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

struct AudioMessage: RTMPBaseMessage {
  let data: Data
  let msgStreamId: Int
  let timestamp: UInt32

  var messageType: MessageType { .audio }
  var streamId: UInt16 { RTMPChunkStreamId.audio.rawValue }
  var payload: Data { data }
  var priority: MessagePriority { .medium }
}
