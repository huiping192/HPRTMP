//
//  RTMPConnection.swift
//
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation

public enum RTMPStatus: Sendable {
  case none
  case open
  case connected
  case closed
}

public actor RTMPConnection {

  private let connection: any NetworkConnectable

  private var status: RTMPStatus = .none

  // AsyncStream for events (public)
  public let mediaEvents: AsyncStream<RTMPMediaEvent>
  public let streamEvents: AsyncStream<RTMPStreamEvent>
  public let connectionEvents: AsyncStream<RTMPConnectionEvent>
  public let logEvents: AsyncStream<RTMPLogEvent>

  // Event dispatcher (manages continuations internally)
  private let eventDispatcher: RTMPEventDispatcher

  // Message router (routes messages to appropriate handlers)
  private let messageRouter: MessageRouter

  // Continuations for async operations
  private var connectContinuation: CheckedContinuation<Void, Error>?
  private var streamCreationContinuations: [Int: CheckedContinuation<MessageStreamId, Error>] = [:]

  private(set) var urlInfo: RTMPURLInfo?

  private let transactionIdGenerator = TransactionIdGenerator()

  let messageHolder = MessageHolder()

  private let encoder = MessageEncoder()
  private let decoder: MessageDecoder

  private var handshake: RTMPHandshake?

  private let windowControl: WindowControl

  private let messagePriorityQueue = MessagePriorityQueue()
  private let tokenBucket: TokenBucket = TokenBucket()

  private let urlParser = RTMPURLParser()

  private let logger: RTMPLogger
  private let logContinuation: AsyncStream<RTMPLogEvent>.Continuation

  // Background task actors
  private let mediaStatisticsCollector = MediaStatisticsCollector()
  private let messageSender: MessageSender
  private let messageReceiver: MessageReceiver
  private let transmissionMonitor: TransmissionMonitor

  public init(connection: (any NetworkConnectable)? = nil) async {
    // Create log stream first so all components share the same continuation
    let (logEvents, logCont) = AsyncStream<RTMPLogEvent>.makeStream()
    self.logEvents = logEvents
    self.logContinuation = logCont

    let resolvedConnection: any NetworkConnectable = connection ?? NetworkClient(
      logger: RTMPLogger(category: "Network", continuation: logCont)
    )
    self.connection = resolvedConnection

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

    self.logger = RTMPLogger(category: "RTMPConnection", continuation: logCont)
    self.windowControl = WindowControl(logger: RTMPLogger(category: "WindowControl", continuation: logCont))
    self.decoder = MessageDecoder(logger: RTMPLogger(category: "MessageDecoder", continuation: logCont))

    // Initialize message router with all handlers
    self.messageRouter = MessageRouter(
      handlers: [
        FlowControlMessageHandler(logger: RTMPLogger(category: "FlowControl", continuation: logCont)),
        CommandMessageHandler(logger: RTMPLogger(category: "Command", continuation: logCont)),
        MediaMessageHandler(logger: RTMPLogger(category: "Media", continuation: logCont)),
        UserControlMessageHandler(logger: RTMPLogger(category: "UserControl", continuation: logCont)),
        ControlMessageHandler(logger: RTMPLogger(category: "Control", continuation: logCont)),
        DataMessageHandler(logger: RTMPLogger(category: "Data", continuation: logCont)),
        SharedObjectMessageHandler(logger: RTMPLogger(category: "SharedObject", continuation: logCont)),
        AbortMessageHandler(logger: RTMPLogger(category: "Abort", continuation: logCont))
      ],
      logger: RTMPLogger(category: "MessageRouter", continuation: logCont)
    )

    // Initialize background task actors
    self.messageSender = MessageSender(
      priorityQueue: messagePriorityQueue,
      encoder: encoder,
      windowControl: windowControl,
      tokenBucket: tokenBucket,
      mediaStatistics: mediaStatisticsCollector,
      sendData: { [resolvedConnection, windowControl] data in
        try await resolvedConnection.sendData(data)
        await windowControl.addOutBytesCount(UInt32(data.count))
      },
      logger: RTMPLogger(category: "MessageSender", continuation: logCont)
    )

    self.messageReceiver = MessageReceiver(
      receiveData: { [resolvedConnection] in
        try await resolvedConnection.receiveData()
      },
      windowControl: windowControl,
      decoder: decoder,
      logger: RTMPLogger(category: "MessageReceiver", continuation: logCont)
    )

    self.transmissionMonitor = TransmissionMonitor(
      priorityQueue: messagePriorityQueue,
      windowControl: windowControl,
      mediaStatistics: mediaStatisticsCollector,
      eventDispatcher: eventDispatcher,
      logger: RTMPLogger(category: "TransmissionMonitor", continuation: logCont)
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
extension RTMPConnection {
  public func openTransport(url: String) async throws {
    guard let urlInfo = try? urlParser.parse(url: url) else {
      throw RTMPError.unknown(desc: "Invalid URL")
    }
    self.urlInfo = urlInfo

    do {
      try await connection.connect(host: urlInfo.host, port: urlInfo.port, enableTLS: urlInfo.isSecure)
      status = .open
    } catch {
      logger.error("[HPRTMP] connection error: \(error.localizedDescription)")
      throw RTMPError.unknown(desc: error.localizedDescription)
    }
  }

  public func performHandshake() async throws {
    guard status == .open else {
      throw RTMPError.handShake(desc: "Transport not open")
    }
    self.handshake = RTMPHandshake(
      client: connection,
      logger: RTMPLogger(category: "Handshake", continuation: logContinuation)
    )

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

  public func createStream() async throws -> MessageStreamId {
    guard status == .connected else {
      throw RTMPError.connectionNotEstablished
    }

    let transactionId = await transactionIdGenerator.nextId()
    let msg = CreateStreamMessage(transactionId: transactionId)

    await messageHolder.register(transactionId: msg.transactionId, message: msg)
    await send(message: msg, firstType: true)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MessageStreamId, Error>) in
      self.streamCreationContinuations[transactionId] = continuation
    }
  }

  public func connect(url: String) async throws {
    try await openTransport(url: url)
    try await performHandshake()
    try await establishConnection()
  }

  public func connect(streamURL: URL, streamKey: String, port: Int = 1935, enableTLS: Bool = false) async throws {
    let scheme = enableTLS ? "rtmps" : "rtmp"
    let urlInfo = RTMPURLInfo(url: streamURL, scheme: scheme, isSecure: enableTLS, appName: "", key: streamKey, port: port)
    self.urlInfo = urlInfo
    try await connection.connect(host: streamURL.host ?? "", port: port, enableTLS: enableTLS)
    status = .open
    try await performHandshake()
    try await establishConnection()
  }

  public func invalidate() async {
    guard status != .closed && status != .none else { return }

    // Close TCP first so blocked receiveData() in MessageReceiver throws an error,
    // allowing messageReceiver.stop() → await task?.value to complete without deadlocking.
    try? await connection.close()

    // Stop all background task actors
    await messageSender.stop()
    await messageReceiver.stop()
    await transmissionMonitor.stop()

    // Clean up pending continuations to prevent resource leaks
    connectContinuation?.resume(throwing: RTMPError.connectionInvalidated)
    connectContinuation = nil

    for continuation in streamCreationContinuations.values {
      continuation.resume(throwing: RTMPError.connectionInvalidated)
    }
    streamCreationContinuations.removeAll()

    await handshake?.reset()
    await decoder.reset()
    await encoder.reset()
    urlInfo = nil
    status = .closed
    await eventDispatcher.yieldConnection(.disconnected)
    await eventDispatcher.finish()
    logContinuation.finish()
  }
}

extension RTMPConnection {
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

extension RTMPConnection {
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
      }
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

  private func handleCreateStreamResult(transactionId: Int, result: Result<MessageStreamId, Error>) {
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
