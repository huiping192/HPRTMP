//
//  RTMPPlayerSession.swift
//  
//
//  Created by 郭 輝平 on 2023/09/25.
//

import Foundation
import os

public protocol RTMPPlayerSessionDelegate: Actor {
  func sessionStatusChange(_ session: RTMPPlayerSession,  status: RTMPPlayerSession.Status)
  func sessionError(_ session: RTMPPlayerSession,  error: RTMPError)
  
}

public actor RTMPPlayerSession {
  public enum Status: Equatable {
    case unknown
    case handShakeStart
    case handShakeDone
    case connect
    case playStart
    case failed(err: RTMPError)
    case disconnected
    
    public static func ==(lhs: Status, rhs: Status) -> Bool {
      switch (lhs, rhs) {
      case (.unknown, .unknown),
        (.connect, .connect),
        (.playStart, .playStart),
        (.disconnected, .disconnected):
        return true
      case let (.failed(err1), .failed(err2)):
        return err1.localizedDescription == err2.localizedDescription
      default:
        return false
      }
    }
  }
  
  public weak var delegate: RTMPPlayerSessionDelegate?
  public func setDelegate(_ delegate: RTMPPlayerSessionDelegate?) {
    self.delegate = delegate
  }
  
  public var status: Status = .unknown {
    didSet {
      Task {
        await delegate?.sessionStatusChange(self, status: status)
      }
    }
  }
  
  public let encodeType: ObjectEncodingType = .amf0
  
  private var socket: RTMPSocket!
  
  private let transactionIdGenerator = TransactionIdGenerator()
  
  private var configure: PublishConfigure?
  
  private var connectId: Int = 0
  
  private let logger = Logger(subsystem: "HPRTMP", category: "Player")

  
  public init() {}
  
  public func publish(url: String, configure: PublishConfigure) async {
    self.configure = configure
    if socket != nil {
      await socket.invalidate()
    }
    socket = await RTMPSocket()
    await socket.setDelegate(delegate: self)
    await socket.connect(url: url)
    
    status = .handShakeStart
  }
  
 
  public func invalidate() async {
    // send closeStream
    let closeStreamMessage = CloseStreamMessage(msgStreamId: connectId)
    await socket.send(message: closeStreamMessage, firstType: true)
    
    // send deleteStream
    let deleteStreamMessage = DeleteStreamMessage(msgStreamId: connectId)
    await socket.send(message: deleteStreamMessage, firstType: true)
    
    await self.socket.invalidate()
    self.status = .disconnected
  }
}

extension RTMPPlayerSession: RTMPSocketDelegate {
  
  
  // publisher dont need implement
  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse) {
    
  }
  
  func socketStreamOutputAudio(_ socket: RTMPSocket, data: Data, timeStamp: Int64) {
    
  }
  func socketStreamOutputVideo(_ socket: RTMPSocket, data: Data, timeStamp: Int64) {
    
  }
  func socketStreamRecord(_ socket: RTMPSocket) {}
  
  func socketStreamPlayStart(_ socket: RTMPSocket) {
    
    
  }
  func socketStreamPause(_ socket: RTMPSocket, pause: Bool) {
    
    
  }
  
  
  func socketStreamPublishStart(_ socket: RTMPSocket) {}
  
  func socketConnectDone(_ socket: RTMPSocket) {
    Task {
      let message = CreateStreamMessage(encodeType: encodeType, transactionId: await transactionIdGenerator.nextId())
      await self.socket.messageHolder.register(transactionId: message.transactionId, message: message)
      await socket.send(message: message, firstType: true)
      
      // make chunk size more bigger
      let chunkSize: UInt32 = 128 * 6
      let size = ChunkSizeMessage(size: chunkSize)
      await socket.send(message: size, firstType: true)
    }
  }
  
  func socketHandShakeDone(_ socket: RTMPSocket) {
    Task {
      status = .handShakeDone
      
      guard let urlInfo = await socket.urlInfo else { return }
      let connect = ConnectMessage(encodeType: encodeType,
                                   tcUrl: urlInfo.tcUrl,
                                   appName: urlInfo.appName,
                                   flashVer: "FMLE/3.0 (compatible; FMSc/1.0)",
                                   fpad: false,
                                   audio: .aac,
                                   video: .h264)
      await self.socket.messageHolder.register(transactionId: connect.transactionId, message: connect)
      await self.socket.send(message: connect, firstType: true)
    }
  }
  
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int) {
    Task {
      status = .connect
      
      let message = await PlayMessage(streamName: socket.urlInfo?.key ?? "")
      
      message.msgStreamId = msgStreamId
      self.connectId = msgStreamId
      await socket.send(message: message, firstType: true)
    }
  }
  
  func socketPinRequest(_ socket: RTMPSocket, data: Data) {
    Task {
      let message = UserControlMessage(type: .pingResponse, data: data, streamId: UInt16(connectId))
      await socket.send(message: message, firstType: true)
    }
  }
  
  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    Task {
      await delegate?.sessionError(self, error: err)
    }
  }
  
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32) {
    Task {
      // send window ack message  to server
      await socket.send(message: WindowAckMessage(size: size), firstType: true)
    }
  }
  
  func socketDisconnected(_ socket: RTMPSocket) {
    status = .disconnected
  }
  
  func socketStreamStatistics(_ socket: RTMPSocket, statistics: TransmissionStatistics) {
  }
}

