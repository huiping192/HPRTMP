//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public struct PublishConfigure {
  let width: Int
  let height: Int
  let displayWidth: Int
  let displayHeight: Int
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  let videoframerate: Int
  
  public init(width: Int, height: Int, displayWidth: Int, displayHeight: Int, videocodecid: Int, audiocodecid: Int, framerate: Int, videoframerate: Int) {
    self.width = width
    self.height = height
    self.displayWidth = displayWidth
    self.displayHeight = displayHeight
    self.videocodecid = videocodecid
    self.audiocodecid = audiocodecid
    self.framerate = framerate
    self.videoframerate = videoframerate
  }
  
  var meta: [String: Any] {
    return [
      "width": Int32(width),
      "height": Int32(height),
      "displayWidth": Int32(displayWidth),
      "displayHeight": Int32(displayHeight),
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate,
      "videoframerate": videoframerate
    ]
  }
}


public protocol RTMPPublishSessionDelegate: AnyObject {
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
  
  private let transactionIdGenerator = TransactionIdGenerator()
  
  private var configure: PublishConfigure?
  
  private var connectId: Int?
  
  public init() {}
  
  public func publish(url: String, configure: PublishConfigure) {
    self.configure = configure
    socket.delegate = self
    socket.connect(url: url)
  }
    
  public func publishVideo(data: Data, delta: UInt32) async throws {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    try await socket.send(message: message, firstType: false)
  }
  
  public func publishVideoHeader(data: Data, time: UInt32) async throws {
    let message = VideoMessage(msgStreamId: socket.connectId, data: data, timestamp: time)
    try await socket.send(message: message, firstType: true)
  }
  
  public func publishAudio(data: Data, delta: UInt32) async throws {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: delta)
    try await socket.send(message: message, firstType: false)
  }
  
  public func publishAudioHeader(data: Data, time: UInt32) async throws {
    let message = AudioMessage(msgStreamId: socket.connectId, data: data, timestamp: 0)
    try await socket.send(message: message, firstType: true)
  }
  
}

extension RTMPPublishSession: RTMPSocketDelegate {
  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse) {
    
  }
  
  func socketStreamOutputAudio(_ socket: RTMPSocket, data: Data, timeStamp: Int64, isFirst: Bool) {
    
  }
  
  func socketStreamOutputVideo(_ socket: RTMPSocket, data: Data, timeStamp: Int64, isFirst: Bool) {
    
  }
  
  func socketStreamPublishStart(_ socket: RTMPSocket) {
    print("[HPRTMP] socketStreamPublishStart")
    Task {
      guard let configure = configure, let connectId = connectId else { return }
      let metaMessage = MetaMessage(encodeType: encodeType, msgStreamId: connectId, meta: configure.meta)
      try await socket.send(message: metaMessage)
    }
  }
  
  func socketStreamRecord(_ socket: RTMPSocket) {
    
  }
  
  func socketStreamPlayStart(_ socket: RTMPSocket) {
    
  }
  
  func socketStreamPause(_ socket: RTMPSocket, pause: Bool) {
    
  }

  func socketConnectDone(_ socket: RTMPSocket) {
    Task {
      let message = CreateStreamMessage(encodeType: encodeType, transactionId: await transactionIdGenerator.nextId())
      await self.socket.messageHolder.register(message: message)
      try await socket.send(message: message)
      
      // make chunk size more bigger
      let chunkSize: UInt32 = 1024*10
      let size = ChunkSizeMessage(size: chunkSize)
      try await socket.send(message: size)
    }
  }
  
  func socketHandShakeDone(_ socket: RTMPSocket) {
    Task {
      let connect = ConnectMessage(encodeType: encodeType,
                                   url: socket.urlInfo!.url,
                                   flashVer: flashVer,
                                   fpad: false,
                                   audio: .aac,
                                   video: .h264)
      await self.socket.messageHolder.register(message: connect)
      do {
        try await self.socket.send(message: connect, firstType: true)
      } catch {
        // todo
      }
    }
  }
  
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int) {
    Task {
      let message = PublishMessage(encodeType: encodeType, streamName: "HPRTMP", type: .live)

      message.msgStreamId = msgStreamId
      self.connectId = msgStreamId
      try await socket.send(message: message)
      publishStatus = .connect
    }
  }
  
  func socketPinRequest(_ socket: RTMPSocket, data: Data) {
//    let message = UserControlMessage(type: .pingRequest, data: data)
//    socket.send(message: message, firstType: true)
  }
  
  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    // todo : error handling
  }
  
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32) {
  // send window ack message  to server
    Task {
      try await socket.send(message: WindowAckMessage(size: size), firstType: true)
    }
  }
  
  func socketDisconnected(_ socket: RTMPSocket) {
    publishStatus = .disconnected
  }
  
  
}


private actor TransactionIdGenerator {
  private var currentId: Int = 1
  
  func nextId() -> Int {
    currentId += 1
    return currentId
  }
}
