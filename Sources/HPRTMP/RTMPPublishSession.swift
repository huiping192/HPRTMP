//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public class RTMPPublishSession {
  public let encodeType: ObjectEncodingType = .amf0
  let flashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)"

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

extension RTMPPublishSession: RTMPSocketDelegate {
  func socketHandShakeDone(_ socket: RTMPSocket) {
    let connect = ConnectMessage(encodeType: encodeType,
                                 url: socket.urlInfo.url,
                                 flashVer: flashVer,
                                 fpad: false,
                                 audio: .aac,
                                 video: .h264)
//    self.socket.info.register(message: connect)
    self.socket.send(message: connect, firstType: true)
  }
  
  func socketPinRequest(_ socket: RTMPSocket, data: Data) {
    
  }
  
  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    
  }
  
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32) {
    
  }
  
  func socketDisconnected(_ socket: RTMPSocket) {
    
  }
  
  
}
