//
//  RTMPBaseMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public protocol RTMPBaseMessage: RTMPMessage {
  var messageType: MessageType { get }
  var msgStreamId: Int { get }
  var streamId: UInt16 { get }
  var timestamp: UInt32 { get }
}
