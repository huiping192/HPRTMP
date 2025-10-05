//
//  RTMPBaseMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public protocol RTMPBaseMessage: RTMPMessage {
  var messageType: MessageType { get }
  var msgStreamId: MessageStreamId { get }
  var streamId: ChunkStreamId { get }
  var timestamp: Timestamp { get }
}
