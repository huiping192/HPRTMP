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
  case invalidChunkSize(size: UInt32, min: UInt32, max: UInt32)

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
      case .invalidChunkSize(let size, let min, let max):
        return "Invalid chunk size: \(size). Must be between \(min) and \(max)"
      }
    }
  }
}

public struct TransmissionStatistics: Sendable {
  // todo
//  let rtt: Int

  let pendingMessageCount: Int
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

  // Continuations for async operations
  private var connectContinuation: CheckedContinuation<Void, Error>?
  private var streamCreationContinuations: [Int: CheckedContinuation<Int, Error>] = [:]
  
  private(set) var urlInfo: RTMPURLInfo?

  private let transactionIdGenerator = TransactionIdGenerator()

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
}

// public func
extension RTMPSocket {
  public func openTransport(url: String) async throws {
    guard let urlInfo = try? urlParser.parse(url: url) else {
      throw RTMPError.uknown(desc: "Invalid URL")
    }
    self.urlInfo = urlInfo

    do {
      try await connection.connect(host: urlInfo.host, port: urlInfo.port)
      status = .open
    } catch {
      logger.error("[HPRTMP] connection error: \(error.localizedDescription)")
      throw RTMPError.uknown(desc: error.localizedDescription)
    }
  }

  public func performHandshake() async throws {
    guard status == .open else {
      throw RTMPError.handShake(desc: "Transport not open")
    }
    guard let client = connection as? NetworkClient else {
      throw RTMPError.handShake(desc: "Invalid connection type")
    }

    self.handshake = RTMPHandshake(client: client)

    do {
      try await self.handshake?.start()
    } catch {
      throw RTMPError.handShake(desc: error.localizedDescription)
    }

    // Start background tasks after handshake completes
    startSendMessages()
    startReceiveData()
    startUpdateTransmissionStatistics()
  }

  public func establishConnection() async throws {
    guard status == .open else {
      throw RTMPError.connectionNotEstablished
    }
    guard let urlInfo else {
      throw RTMPError.connectionNotEstablished
    }

    let connectMsg = ConnectMessage(
      tcUrl: urlInfo.tcUrl,
      appName: urlInfo.appName,
      flashVer: "LNX 9,0,124,2",
      fpad: false,
      audio: .aac,
      video: .h264
    )

    await messageHolder.register(transactionId: connectMsg.transactionId, message: connectMsg)
    await send(message: connectMsg, firstType: true)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.connectContinuation = continuation
    }

    status = .connected
  }

  public func createStream() async throws -> Int {
    guard status == .connected else {
      throw RTMPError.connectionNotEstablished
    }

    let transactionId = await transactionIdGenerator.nextId()
    let msg = CreateStreamMessage(transactionId: transactionId)

    await messageHolder.register(transactionId: msg.transactionId, message: msg)
    await send(message: msg, firstType: true)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
      self.streamCreationContinuations[transactionId] = continuation
    }
  }

  public func connect(url: String) async throws {
    try await openTransport(url: url)
    try await performHandshake()
    try await establishConnection()
  }

  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) async throws {
    let urlInfo = RTMPURLInfo(url: streamURL, appName: "", key: streamKey, port: port)
    self.urlInfo = urlInfo
    try await openTransport(url: streamURL.absoluteString)
    try await performHandshake()
    try await establishConnection()
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
          do {
            try await encoder.setChunkSize(chunkSize: message.size)
          } catch {
            logger.error("[HPRTMP] Invalid chunk size: \(error.localizedDescription), using default chunk size")
            // Continue with default chunk size instead of invalidating connection
          }
        }
        let chunkDataList = await encoder.encode(message: message, isFirstType0: isFirstType).map({ $0.encode() })
        
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

                // Log the error
                logger.error("[HPRTMP] Send error: \(error.localizedDescription)")

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
        logger.error("Status error: \(statusResponse.description ?? "")")
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
          connectContinuation?.resume()
          connectContinuation = nil
        } else {
          logger.error("Connect failed")
          let error = RTMPError.command(desc: connectResponse?.code.rawValue ?? "Connect error")
          connectContinuation?.resume(throwing: error)
          connectContinuation = nil
        }
      }
    case is CreateStreamMessage:
      if commandMessage.commandNameType == .result {
        logger.info("Create Stream Success")
        self.status = .connected

        let streamId = Int(commandMessage.info?.doubleValue ?? 0)
        streamCreationContinuations[commandMessage.transactionId]?.resume(returning: streamId)
        streamCreationContinuations.removeValue(forKey: commandMessage.transactionId)
      } else {
        logger.error("Create Stream failed, \(commandMessage.info.debugDescription)")
        let error = RTMPError.command(desc: "Create Stream error")
        streamCreationContinuations[commandMessage.transactionId]?.resume(throwing: error)
        streamCreationContinuations.removeValue(forKey: commandMessage.transactionId)
      }
    default:
      break
    }
  }
}
