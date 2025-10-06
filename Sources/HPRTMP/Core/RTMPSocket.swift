//
//  RTMPSocket.swift
//
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import os

public enum RTMPStatus: Sendable {
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

public actor RTMPSocket {

  private let connection: NetworkConnectable = NetworkClient()

  private var status: RTMPStatus = .none

  // AsyncStream for events (public)
  public let mediaEvents: AsyncStream<RTMPMediaEvent>
  public let streamEvents: AsyncStream<RTMPStreamEvent>
  public let connectionEvents: AsyncStream<RTMPConnectionEvent>

  // Event dispatcher (manages continuations internally)
  private let eventDispatcher: RTMPEventDispatcher

  // Message router (routes messages to appropriate handlers)
  private let messageRouter: MessageRouter

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

  // Background task actors
  private let mediaStatisticsCollector = MediaStatisticsCollector()
  private let messageSender: MessageSender
  private let messageReceiver: MessageReceiver
  private let transmissionMonitor: TransmissionMonitor

  public init() async {
    // Initialize AsyncStreams and capture continuations
    let (mediaEvents, mediaCont) = AsyncStream<RTMPMediaEvent>.makeStream()
    self.mediaEvents = mediaEvents

    let (streamEvents, streamCont) = AsyncStream<RTMPStreamEvent>.makeStream()
    self.streamEvents = streamEvents

    let (connectionEvents, connCont) = AsyncStream<RTMPConnectionEvent>.makeStream()
    self.connectionEvents = connectionEvents

    // Initialize event dispatcher with continuations
    self.eventDispatcher = RTMPEventDispatcher(
      mediaContinuation: mediaCont,
      streamContinuation: streamCont,
      connectionContinuation: connCont
    )

    // Initialize message router with all handlers
    self.messageRouter = MessageRouter(handlers: [
      FlowControlMessageHandler(),
      CommandMessageHandler(),
      MediaMessageHandler(),
      UserControlMessageHandler(),
      ControlMessageHandler(),
      DataMessageHandler(),
      SharedObjectMessageHandler(),
      AbortMessageHandler()
    ])

    // Initialize background task actors
    self.messageSender = MessageSender(
      priorityQueue: messagePriorityQueue,
      encoder: encoder,
      windowControl: windowControl,
      tokenBucket: tokenBucket,
      mediaStatistics: mediaStatisticsCollector,
      sendData: { [connection, windowControl] data in
        try await connection.sendData(data)
        await windowControl.addOutBytesCount(UInt32(data.count))
      },
      logger: logger
    )

    self.messageReceiver = MessageReceiver(
      receiveData: { [connection] in
        try await connection.receiveData()
      },
      windowControl: windowControl,
      decoder: decoder,
      logger: logger
    )

    self.transmissionMonitor = TransmissionMonitor(
      priorityQueue: messagePriorityQueue,
      windowControl: windowControl,
      mediaStatistics: mediaStatisticsCollector,
      eventDispatcher: eventDispatcher,
      logger: logger
    )

    await windowControl.setInBytesWindowEvent { [weak self] inbytesCount in
      await self?.sendAcknowledgementMessage(sequence: inbytesCount)
    }

    // Set handlers after initialization
    await messageSender.setErrorHandler { [weak self] in
      await self?.invalidate()
    }

    await messageReceiver.setMessageHandler { [weak self] data in
      await self?.handleOutputData(data: data)
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

    // Start background task actors after handshake completes
    await messageSender.start()
    await messageReceiver.start()
    await transmissionMonitor.start()
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

    // Stop all background task actors
    await messageSender.stop()
    await messageReceiver.stop()
    await transmissionMonitor.stop()

    await handshake?.reset()
    await decoder.reset()
    try? await connection.close()
    urlInfo = nil
    status = .closed
    await eventDispatcher.yieldConnection(.disconnected)
  }
}

extension RTMPSocket {
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
    // Create context with all dependencies
    let context = MessageHandlerContext(
      windowControl: windowControl,
      tokenBucket: tokenBucket,
      decoder: decoder,
      messageHolder: messageHolder,
      eventDispatcher: eventDispatcher,
      resumeConnect: { @Sendable [weak self] result in
        Task { [weak self] in
          await self?.handleConnectResult(result)
        }
      },
      resumeCreateStream: { @Sendable [weak self] transactionId, result in
        Task { [weak self] in
          await self?.handleCreateStreamResult(transactionId: transactionId, result: result)
        }
      },
      updateStatus: { @Sendable [weak self] newStatus in
        Task { [weak self] in
          await self?.updateStatus(newStatus)
        }
      },
      logger: logger
    )

    // Route message to appropriate handler
    await messageRouter.route(message, context: context)
  }

  private func handleConnectResult(_ result: Result<Void, Error>) {
    switch result {
    case .success:
      connectContinuation?.resume()
      connectContinuation = nil
    case .failure(let error):
      connectContinuation?.resume(throwing: error)
      connectContinuation = nil
    }
  }

  private func handleCreateStreamResult(transactionId: Int, result: Result<Int, Error>) {
    switch result {
    case .success(let streamId):
      streamCreationContinuations[transactionId]?.resume(returning: streamId)
      streamCreationContinuations.removeValue(forKey: transactionId)
    case .failure(let error):
      streamCreationContinuations[transactionId]?.resume(throwing: error)
      streamCreationContinuations.removeValue(forKey: transactionId)
    }
  }

  private func updateStatus(_ newStatus: RTMPStatus) {
    status = newStatus
  }
}
