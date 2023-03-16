//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public protocol RTMPPublishSessionDelegate: AnyObject {
    func sessionMetaData(_ session: RTMPPublishSession) -> [String: Any]
    func sessionStatusChange(_ session: RTMPPublishSession,  status: RTMPPublishSession.Status)
}

public class RTMPPublishSession {
  public enum Status {
      case unknown
      case connect
      case publishStart
      case failed(err: RTMPError)
      case disconnected
  }
  
  public weak var delegate: RTMPPublishSessionDelegate?

  public var publishStatus: Status = .unknown {
    didSet {
      delegate?.sessionStatusChange(self, status: publishStatus)
    }
  }
  
  public let encodeType: ObjectEncodingType = .amf0
  let flashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)"

  private let socket = RTMPSocket()
  
  public func publish(url: String) {
    socket.connect(url: url)
  }
  
  public func publishVideo(data: Data, delta: TimeInterval) async throws {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    try await socket.send(message: message, firstType: false)
  }
  
  public func publishVideoHeader(data: Data, time: TimeInterval) async throws {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: time)
    try await socket.send(message: message, firstType: true)
  }
  
  public func publishAudio(data: Data, delta: TimeInterval) async throws {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    try await socket.send(message: message, firstType: false)
  }
  
  public func publishAudioHeader(data: Data, time: TimeInterval) async throws {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: 0)
    try await socket.send(message: message, firstType: true)
  }
  
}

extension RTMPPublishSession: RTMPSocketDelegate {
  func socketHandShakeDone(_ socket: RTMPSocket) {
    Task {
      let connect = ConnectMessage(encodeType: encodeType,
                                   url: socket.urlInfo!.url,
                                   flashVer: flashVer,
                                   fpad: false,
                                   audio: .aac,
                                   video: .h264)
      // fixme: dont know why should cache message!!!
      await self.socket.messageHolder.register(message: connect)
      try await self.socket.send(message: connect, firstType: true)
    }
  }
  
  func socketPinRequest(_ socket: RTMPSocket, data: Data) {
//    let message = UserControlMessage(type: .pingRequest, data: data)
//    self.socket.send(message: message, firstType: true)
  }
  
  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    // todo : error handling
  }
  
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32) {
//    self.socket.send(message: WindowAckMessage(size: size), firstType: true)
  }
  
  func socketDisconnected(_ socket: RTMPSocket) {
    
  }
  
  
}
