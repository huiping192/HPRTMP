//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public class RTMPPublishSession {
  
  // todo: 値設定
  public var socket = RTMPSocket(streamURL: URL(string: "")!, streamKey: "")!

  
  public func publishVideo(data: Data, delta: TimeInterval) {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    socket.send(message: message, firstType: false)
  }
  
  public func publishVideoHeader(data: Data, time: TimeInterval) {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: time)
    socket.send(message: message, firstType: true)
  }
  
  public func publishAudio(data: Data, delta: TimeInterval) {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    socket.send(message: message, firstType: false)
  }
  
  public func publishAudioHeader(data: Data, time: TimeInterval) {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: 0)
    socket.send(message: message, firstType: true)
  }
  
}
