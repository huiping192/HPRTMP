//
//  RTMPSocket.swift
//
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import os

public enum RTMPStatus {
  case none
  case open
  case connected
  case closed
}

public enum RTMPError: Error {
  case handShake(desc: String)
  case stream(desc: String)
  case command(desc: String)
  case uknown(desc: String)
  var localizedDescription: String {
    get {
      switch self {
      case .handShake(let desc):
        return desc
      case .stream(let desc):
        return desc
      case .command(let desc):
        return desc
      case .uknown(let desc):
        return desc
      }
    }
  }
}

public struct TransmissionStatistics {
  // todo
//  let rtt: Int
  
  let pendingMessageCount: Int
}

protocol RTMPSocketDelegate: Actor {
  func socketHandShakeDone(_ socket: RTMPSocket)
  func socketPinRequest(_ socket: RTMPSocket, data: Data)
  func socketConnectDone(_ socket: RTMPSocket)
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int)
  func socketError(_ socket: RTMPSocket, err: RTMPError)
  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse)
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32)
  func socketDisconnected(_ socket: RTMPSocket)
  
  
  func socketStreamOutputAudio(_ socket: RTMPSocket, data: Data, timeStamp: Int64)
  func socketStreamOutputVideo(_ socket: RTMPSocket, data: Data, timeStamp: Int64)
  func socketStreamPublishStart(_ socket: RTMPSocket)
  func socketStreamRecord(_ socket: RTMPSocket)
  func socketStreamPlayStart(_ socket: RTMPSocket)
  func socketStreamPause(_ socket: RTMPSocket, pause: Bool)
  
  func socketStreamStatistics(_ socket: RTMPSocket, statistics: TransmissionStatistics)
}

public actor RTMPSocket {
  
  private let connection: NetworkConnectable = NetworkClient()
  
  private var status: RTMPStatus = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  func setDelegate(delegate: RTMPSocketDelegate) {
    self.delegate = delegate
  }
  
  private(set) var urlInfo: RTMPURLInfo?
  
  let messageHolder = MessageHolder()
  
  private let encoder = MessageEncoder()
  private let decoder = MessageDecoder()
  
  private var handshake: RTMPHandshake?
  
  private let windowControl = WindowControl()
  
  private let messagePriorityQueue = PriorityQueue()
  private let tokenBucket: TokenBucket = TokenBucket()
  
  private let urlParser = RTMPURLParser()
  
  private let logger = Logger(subsystem: "HPRTMP", category: "RTMPSocket")
  
  private var tasks: [Task<Void, Never>] = []
    
  public init() async {
    await windowControl.setInBytesWindowEvent { [weak self]inbytesCount in
      await self?.sendAcknowledgementMessage(sequence: inbytesCount)
    }
  }
  
  private func sendAcknowledgementMessage(sequence: UInt32) async {
    guard status == .connected else { return }
    await self.send(message: AcknowledgementMessage(sequence: UInt32(sequence)), firstType: true)
  }
  
  
  public func connect(url: String) async {
    guard let urlInfo = try? urlParser.parse(url: url) else { return }
    self.urlInfo = urlInfo
    
    await resume()
  }
  
  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) {
    let urlInfo = RTMPURLInfo(url: streamURL, appName: "", key: streamKey, port: port)
    self.urlInfo = urlInfo
  }
}

// public func
extension RTMPSocket {
  public func resume() async {
    guard status != .connected else { return }
    guard let urlInfo else { return }
    do {
      try await connection.connect(host: urlInfo.host, port: urlInfo.port)
      status = .open
      Task {
        await self.startShakeHands()
      }
    } catch {
      self.logger.error("[HPRTMP] connection error: \(error.localizedDescription)")
      await self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
      await self.invalidate()
    }
  }
  
  private func startShakeHands() async {
    self.handshake = RTMPHandshake(dataSender: connection.sendData(_:), dataReceiver: receiveData)
    await self.handshake?.setDelegate(delegate: self)
    do {
      try await self.handshake?.start()
    } catch {
      await self.delegate?.socketError(self, err: .handShake(desc: error.localizedDescription))
    }
  }
  
  public func invalidate() async {
    guard status != .closed && status != .none else { return }
    tasks.forEach {
      $0.cancel()
    }
    await handshake?.reset()
    await decoder.reset()
    try? await connection.close()
    urlInfo = nil
    status = .closed
    await delegate?.socketDisconnected(self)
  }
  
  private func startSendMessages() {
    let task = Task {
      while !Task.isCancelled {
        let messageContainer = await messagePriorityQueue.dequeue()
        let message = messageContainer.message
        let isFirstType = messageContainer.isFirstType
        // windows sizeが超えた場合acknowledgementまち
        if await windowControl.shouldWaitAcknowledgement {
          logger.info("[HPRTMP] Window size reached, waiting for acknowledgement...")
          continue
        }
        
        logger.debug("send message start: \(type(of: message))")
        
        if let message = message as? ChunkSizeMessage {
          encoder.chunkSize = message.size
        }
        let chunkDataList = encoder.encode(message: message, isFirstType0: isFirstType).map({ $0.encode() })
        
        for chunkData in chunkDataList {
          var successfullySent = false
          while !successfullySent {
            if await tokenBucket.consume(tokensNeeded: chunkData.count) {
              logger.debug("[HPRTMP] token bucket consume: \(chunkData.count)")
              do {
                try await sendData(chunkData)
                logger.info("[HPRTMP] send message successd: \(type(of: message))")
                successfullySent = true
              } catch {
                logger.error("[HPRTMP] send message failed: \(type(of: message)), error: \(error)")
                await delegate?.socketError(self, err: .stream(desc: error.localizedDescription))
                return
              }
            } else {
              logger.info("[HPRTMP] token bucket is empty, waiting...")
              // wait 10ms
              try? await Task.sleep(nanoseconds:  UInt64(10 * 1000 * 1000))
            }
          }
        }
      }
    }
    
    tasks.append(task)
  }
  
  private func startReceiveData() {
    let task = Task {
      while !Task.isCancelled {
        do {
          let data = try await receiveData()
          logger.debug("receive data count: \(data.count)")
          await self.handleOutputData(data: data)
        } catch {
          logger.error("[HPRTMP] receive message failed: error: \(error)")
          await delegate?.socketError(self, err: .stream(desc: error.localizedDescription))
          return
        }
      }
    }
    
    tasks.append(task)
  }
  
  private func startUpdateTransmissionStatistics() {
    let task = Task {
      while !Task.isCancelled {
        // 1 second
        try? await Task.sleep(nanoseconds:  UInt64(1000 * 1000 * 1000))
        
        let pendingMessageCount = await messagePriorityQueue.pendingMessageCount
        let statistics = TransmissionStatistics(pendingMessageCount: pendingMessageCount)
        await delegate?.socketStreamStatistics(self, statistics: statistics)
      }
    }
    
    tasks.append(task)
  }
}

extension RTMPSocket {
  private func sendData(_ data: Data) async throws {
    try await connection.sendData(data)
    await windowControl.addOutBytesCount(UInt32(data.count))
  }
  func send(message: RTMPMessage, firstType: Bool) async {
    await messagePriorityQueue.enqueue(message, firstType: firstType)
  }
  
  private func receiveData() async throws -> Data {
    return try await connection.receiveData()
  }
}

extension RTMPSocket: RTMPHandshakeDelegate {
  nonisolated func rtmpHandshakeDidChange(status: RTMPHandshake.Status) {
    Task {
      guard status == .handshakeDone else { return }
      await self.delegate?.socketHandShakeDone(self)
      
      // start sending messages
      await startSendMessages()
      
      // start receive data
      await startReceiveData()
      
      await startUpdateTransmissionStatistics()
    }
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) async {
    guard !data.isEmpty else { return }
    await windowControl.addInBytesCount(UInt32(data.count))
    await decoder.append(data)
    
    if await decoder.isDecoding {
      return
    }
    var dataRemainCount = 0
    while await decoder.remainDataCount != dataRemainCount, await decoder.remainDataCount != 0 {
      dataRemainCount = await decoder.remainDataCount
      await decode(data: data)
    }
  }
  
  private func decode(data: Data) async {
    guard let message = await decoder.decode() else {
      logger.info("[HPRTMP] decode message need more data. \(data)")
      return
    }
    
    switch message {
    case let windowAckMessage as WindowAckMessage:
      logger.info("WindowAckMessage, size \(windowAckMessage.size)")
      await windowControl.setWindowSize(windowAckMessage.size)
      
    case let acknowledgementMessage as AcknowledgementMessage:
      logger.info("AcknowledgementMessage, size \(acknowledgementMessage.sequence)")
      await windowControl.updateReceivedAcknowledgement(acknowledgementMessage.sequence)
      
    case let peerBandwidthMessage as PeerBandwidthMessage:
      logger.info("PeerBandwidthMessage, size \(peerBandwidthMessage.windowSize)")
      await tokenBucket.update(rate: Int(peerBandwidthMessage.windowSize), capacity: Int(peerBandwidthMessage.windowSize))
      await delegate?.socketPeerBandWidth(self, size: peerBandwidthMessage.windowSize)
      
    case let chunkSizeMessage as ChunkSizeMessage:
      logger.info("chunkSizeMessage, size \(chunkSizeMessage.size)")
      await decoder.setMaxChunkSize(maxChunkSize: Int(chunkSizeMessage.size))
      
    case let commandMessage as CommandMessage:
      logger.info("CommandMessage, \(commandMessage.description)")
      await handleCommandMessage(commandMessage)
      
    case let userControlMessage as UserControlMessage:
      logger.info("UserControlMessage, message Type:  \(userControlMessage.type.rawValue)")
      switch userControlMessage.type {
      case .pingRequest:
        await self.delegate?.socketPinRequest(self, data: userControlMessage.data)
      case .streamIsRecorded:
        await self.delegate?.socketStreamRecord(self)
      default:
        break
      }
      
    case let controlMessage as ControlMessage:
      logger.info("ControlMessage, message Type:  \(controlMessage.messageType.rawValue)")
      
    case let dataMessage as DataMessage:
      logger.info("DataMessage, message Type:  \(dataMessage.messageType.rawValue)")
      
    case let videoMessage as VideoMessage:
      logger.info("VideoMessage, message Type:  \(videoMessage.messageType.rawValue)")
      await self.delegate?.socketStreamOutputVideo(self, data: videoMessage.data, timeStamp: Int64(videoMessage.timestamp))
      
    case let audioMessage as AudioMessage:
      logger.info("AudioMessage, message Type:  \(audioMessage.messageType.rawValue)")
      await self.delegate?.socketStreamOutputAudio(self, data: audioMessage.data, timeStamp: Int64(audioMessage.timestamp))
      
    case let sharedObjectMessage as SharedObjectMessage:
      logger.info("ShareMessage, message Type:  \(sharedObjectMessage.messageType.rawValue)")
      
    case let abortMessage as AbortMessage:
      logger.info("AbortMessage, message Type:  \(abortMessage.chunkStreamId)")
      
    default:
      break
    }
  }
  
  private func handleCommandMessage(_ commandMessage: CommandMessage) async {
    if commandMessage.commandNameType == .onStatus {
      guard let statusResponse = StatusResponse(info: commandMessage.info) else { return }
      if statusResponse.level == .error {
        await self.delegate?.socketError(self, err: .command(desc: statusResponse.description ?? ""))
        return
      }
      switch statusResponse.code {
      case .publishStart:
        await self.delegate?.socketStreamPublishStart(self)
      case .playStart:
        await self.delegate?.socketStreamPlayStart(self)
      case .pauseNotify:
        await self.delegate?.socketStreamPause(self, pause: true)
      case .unpauseNotify:
        await self.delegate?.socketStreamPause(self, pause: false)
      default:
        break
      }
      return
    }
    
    // meta data
    if commandMessage.commandNameType == .onMetaData {
      guard let meta = MetaDataResponse(commandObject: commandMessage.commandObject) else { return }
      await self.delegate?.socketGetMeta(self, meta: meta)
      return
    }
    
    // back from server
    let message = await messageHolder.removeMessage(transactionId: commandMessage.transactionId)
    switch message {
    case is ConnectMessage:
      if commandMessage.commandNameType == .result {
        let connectResponse = ConnectResponse(info: commandMessage.info)
        if connectResponse?.code == .success {
          logger.info("Connect Success")
          await self.delegate?.socketConnectDone(self)
        } else {
          logger.error("Connect failed")
          await self.delegate?.socketError(self, err: .command(desc: connectResponse?.code.rawValue ?? "Connect error"))
        }
      }
    case is CreateStreamMessage:
      if commandMessage.commandNameType == .result {
        logger.info("Create Stream Success")
        self.status = .connected
        
        let msgStreamId = commandMessage.info as? Double ?? 0
        await self.delegate?.socketCreateStreamDone(self, msgStreamId: Int(msgStreamId))
      } else {
        logger.error("Create Stream failed, \(commandMessage.info.debugDescription)")
        await self.delegate?.socketError(self, err: .command(desc: "Create Stream error"))
      }
    default:
      break
    }
  }
}
