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

public enum RTMPError: Error, Sendable {
  case handShake(desc: String)
  case stream(desc: String)
  case command(desc: String)
  case uknown(desc: String)
  case connectionNotEstablished
  case connectionInvalidated
  case dataRetrievalFailed
  case bufferOverflow

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
      case .connectionNotEstablished:
        return "Connection not established"
      case .connectionInvalidated:
        return "Connection invalidated"
      case .dataRetrievalFailed:
        return "Data retrieval failed unexpectedly"
      case .bufferOverflow:
        return "Buffer overflow: received data exceeds maximum allowed size"
      }
    }
  }
}

public struct TransmissionStatistics: Sendable {
  // todo
//  let rtt: Int

  let pendingMessageCount: Int
}

protocol RTMPSocketDelegate: Actor {
  func socketHandShakeDone(_ socket: RTMPSocket)
  func socketConnectDone(_ socket: RTMPSocket)
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int)
  func socketError(_ socket: RTMPSocket, err: RTMPError)
}

public actor RTMPSocket {

  private let connection: NetworkConnectable = NetworkClient()

  private var status: RTMPStatus = .none

  // AsyncStream for media events
  private let mediaContinuation: AsyncStream<RTMPMediaEvent>.Continuation
  public let mediaEvents: AsyncStream<RTMPMediaEvent>

  // AsyncStream for stream events
  private let streamContinuation: AsyncStream<RTMPStreamEvent>.Continuation
  public let streamEvents: AsyncStream<RTMPStreamEvent>

  // AsyncStream for connection events
  private let connectionContinuation: AsyncStream<RTMPConnectionEvent>.Continuation
  public let connectionEvents: AsyncStream<RTMPConnectionEvent>

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
  
  private let messagePriorityQueue = MessagePriorityQueue()
  private let tokenBucket: TokenBucket = TokenBucket()
  
  private let urlParser = RTMPURLParser()
  
  private let logger = Logger(subsystem: "HPRTMP", category: "RTMPSocket")
  
  private var tasks: [Task<Void, Never>] = []
    
  public init() async {
    // Initialize media events stream
    var mediaCont: AsyncStream<RTMPMediaEvent>.Continuation!
    self.mediaEvents = AsyncStream { mediaCont = $0 }
    self.mediaContinuation = mediaCont

    // Initialize stream events stream
    var streamCont: AsyncStream<RTMPStreamEvent>.Continuation!
    self.streamEvents = AsyncStream { streamCont = $0 }
    self.streamContinuation = streamCont

    // Initialize connection events stream
    var connCont: AsyncStream<RTMPConnectionEvent>.Continuation!
    self.connectionEvents = AsyncStream { connCont = $0 }
    self.connectionContinuation = connCont

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
  
  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) async {
    let urlInfo = RTMPURLInfo(url: streamURL, appName: "", key: streamKey, port: port)
    self.urlInfo = urlInfo
    await resume()
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
      let task = Task {
        await self.startShakeHands()
      }
      tasks.append(task)
    } catch {
      self.logger.error("[HPRTMP] connection error: \(error.localizedDescription)")
      await self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
      await self.invalidate()
    }
  }
  
  private func startShakeHands() async {
    guard let client = connection as? NetworkClient else {
      await self.delegate?.socketError(self, err: .handShake(desc: "Invalid connection type"))
      return
    }
    self.handshake = RTMPHandshake(client: client)
    do {
      try await self.handshake?.start()

      await self.delegate?.socketHandShakeDone(self)
      startSendMessages()
      startReceiveData()
      startUpdateTransmissionStatistics()
    } catch {
      await self.delegate?.socketError(self, err: .handShake(desc: error.localizedDescription))
    }
  }
  
  public func invalidate() async {
    guard status != .closed && status != .none else { return }
    tasks.forEach {
      $0.cancel()
    }
    tasks.removeAll()
    await handshake?.reset()
    await decoder.reset()
    try? await connection.close()
    urlInfo = nil
    status = .closed
    connectionContinuation.yield(.disconnected)
  }
  
  private func startSendMessages() {
    let task = Task {
      while !Task.isCancelled {
        guard let messageContainer = await messagePriorityQueue.dequeue() else { break }

        let message = messageContainer.message
        let isFirstType = messageContainer.isFirstType
        // windows sizeが超えた場合acknowledgementまち
        if await windowControl.shouldWaitAcknowledgement {
          logger.info("[HPRTMP] Window size reached, waiting for acknowledgement...")
          await messagePriorityQueue.requeue(messageContainer)
          try? await Task.sleep(nanoseconds: 100_000_000)  // Wait 100ms to avoid busy waiting
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

                // Resume continuation before cleanup
                messageContainer.continuation?.resume()

                // Notify delegate first (check for nil to avoid silent failure)
                if let delegate = self.delegate {
                  await delegate.socketError(self, err: .stream(desc: error.localizedDescription))
                } else {
                  logger.error("[HPRTMP] CRITICAL: delegate is nil, cannot notify error!")
                }

                // Clean up all resources (cancels tasks, closes socket, sets status to .closed)
                await invalidate()

                return
              }
            } else {
              let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: chunkData.count)
              logger.info("[HPRTMP] token bucket is empty, waiting \(waitTime / 1_000_000)ms...")
              try? await Task.sleep(nanoseconds: waitTime)
            }
          }
        }

        // All chunks sent successfully, resume continuation if present
        messageContainer.continuation?.resume()
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
        connectionContinuation.yield(.statistics(statistics))
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

  func sendAndWait(message: RTMPMessage, firstType: Bool) async {
    await withCheckedContinuation { continuation in
      Task {
        await messagePriorityQueue.enqueue(message, firstType: firstType, continuation: continuation)
      }
    }
  }
  
  private func receiveData() async throws -> Data {
    return try await connection.receiveData()
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) async {
    guard !data.isEmpty else { return }
    await windowControl.addInBytesCount(UInt32(data.count))
    await decoder.append(data)

    while true {
      guard let message = await decoder.decode() else {
        break
      }
      await handleDecodedMessage(message)
    }
  }
  
  private func handleDecodedMessage(_ message: RTMPMessage) async {
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
      connectionContinuation.yield(.peerBandwidthChanged(peerBandwidthMessage.windowSize))

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
        streamContinuation.yield(.pingRequest(userControlMessage.data))
      case .streamIsRecorded:
        streamContinuation.yield(.record)
      default:
        break
      }

    case let controlMessage as ControlMessage:
      logger.info("ControlMessage, message Type:  \(controlMessage.messageType.rawValue)")

    case let dataMessage as DataMessage:
      logger.info("DataMessage, message Type:  \(dataMessage.messageType.rawValue)")

    case let videoMessage as VideoMessage:
      logger.info("VideoMessage, message Type:  \(videoMessage.messageType.rawValue)")
      mediaContinuation.yield(.video(data: videoMessage.data, timestamp: Int64(videoMessage.timestamp)))

    case let audioMessage as AudioMessage:
      logger.info("AudioMessage, message Type:  \(audioMessage.messageType.rawValue)")
      mediaContinuation.yield(.audio(data: audioMessage.data, timestamp: Int64(audioMessage.timestamp)))

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
        streamContinuation.yield(.publishStart)
      case .playStart:
        streamContinuation.yield(.playStart)
      case .pauseNotify:
        streamContinuation.yield(.pause(true))
      case .unpauseNotify:
        streamContinuation.yield(.pause(false))
      default:
        break
      }
      return
    }
    
    // meta data
    if commandMessage.commandNameType == .onMetaData {
      guard let meta = MetaDataResponse(commandObject: commandMessage.commandObject) else { return }
      mediaContinuation.yield(.metadata(meta))
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

        let msgStreamId = commandMessage.info?.doubleValue ?? 0
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
