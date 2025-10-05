import Foundation
import os

public protocol RTMPPublishSessionDelegate: Actor {
  func sessionStatusChange(_ session: RTMPPublishSession,  status: RTMPPublishSession.Status)
  func sessionError(_ session: RTMPPublishSession,  error: RTMPError)
  
  // transmission statistics
  func sessionTransmissionStatisticsChanged(_ session: RTMPPublishSession,  statistics: TransmissionStatistics)
}

public actor RTMPPublishSession {
  public enum Status: Equatable, Sendable {
    case unknown
    case handShakeStart
    case handShakeDone
    case connect
    case publishStart
    case failed(err: RTMPError)
    case disconnected
    
    public static func ==(lhs: Status, rhs: Status) -> Bool {
      switch (lhs, rhs) {
      case (.unknown, .unknown),
        (.connect, .connect),
        (.publishStart, .publishStart),
        (.disconnected, .disconnected):
        return true
      case let (.failed(err1), .failed(err2)):
        return err1.localizedDescription == err2.localizedDescription
      default:
        return false
      }
    }
  }
  
  public weak var delegate: RTMPPublishSessionDelegate?
  public func setDelegate(_ delegate: RTMPPublishSessionDelegate?) {
    self.delegate = delegate
  }
  
  public var publishStatus: Status = .unknown {
    didSet {
      Task {
        await delegate?.sessionStatusChange(self, status: publishStatus)
      }
    }
  }
  
  public let encodeType: ObjectEncodingType = .amf0
  
  private var socket: RTMPSocket!
  
  private let transactionIdGenerator = TransactionIdGenerator()
  
  private var configure: PublishConfigure?
  
  private var connectId: Int = 0

  private let logger = Logger(subsystem: "HPRTMP", category: "Publish")

  private var eventTasks: [Task<Void, Never>] = []

  public init() {}
  
  public func publish(url: String, configure: PublishConfigure) async {
    self.configure = configure
    if socket != nil {
      await socket.invalidate()
    }

    // Cancel previous event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    socket = await RTMPSocket()
    let socketRef = socket!

    // Subscribe to stream events
    let streamTask = Task { [socketRef] in
      for await event in socketRef.streamEvents {
        await handleStreamEvent(event)
      }
    }
    eventTasks.append(streamTask)

    // Subscribe to connection events
    let connectionTask = Task { [socketRef] in
      for await event in socketRef.connectionEvents {
        await handleConnectionEvent(event)
      }
    }
    eventTasks.append(connectionTask)

    do {
      publishStatus = .handShakeStart
      try await socket.connect(url: url)
      publishStatus = .handShakeDone

      let streamId = try await socket.createStream()
      self.connectId = streamId
      publishStatus = .connect

      // Send publish message
      let publishMsg = PublishMessage(encodeType: encodeType, streamName: await socket.urlInfo?.key ?? "", type: .live, msgStreamId: streamId)
      await socket.send(message: publishMsg, firstType: true)

      // Send chunk size
      let chunkSize: UInt32 = 128 * 6
      let size = ChunkSizeMessage(size: chunkSize)
      await socket.send(message: size, firstType: true)
    } catch {
      publishStatus = .failed(err: error as? RTMPError ?? .uknown(desc: error.localizedDescription))
      await delegate?.sessionError(self, error: error as? RTMPError ?? .uknown(desc: error.localizedDescription))
    }
  }
  
  private var videoHeaderSended = false
  private var audioHeaderSended = false

  public func publishVideoHeader(data: Data) async {
    let message = VideoMessage(data: data, msgStreamId: connectId, timestamp: 0)
    await socket.send(message: message, firstType: true)
    videoHeaderSended = true
  }

  public func publishVideo(data: Data, delta: UInt32) async {
    guard videoHeaderSended else { return }
    let message = VideoMessage(data: data, msgStreamId: connectId, timestamp: delta)
    await socket.send(message: message, firstType: false)
  }

  public func publishAudioHeader(data: Data) async {
    let message = AudioMessage(data: data, msgStreamId: connectId, timestamp: 0)
    await socket.send(message: message, firstType: true)
    audioHeaderSended = true
  }

  public func publishAudio(data: Data, delta: UInt32) async {
    guard audioHeaderSended else { return }
    let message = AudioMessage(data: data, msgStreamId: connectId, timestamp: delta)
    await socket.send(message: message, firstType: false)
  }
  
  public func invalidate() async {
    // Cancel event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    // send closeStream
    let closeStreamMessage = CloseStreamMessage(msgStreamId: connectId)
    await socket.send(message: closeStreamMessage, firstType: true)

    // send deleteStream and wait for it to be sent
    let deleteStreamMessage = DeleteStreamMessage(msgStreamId: connectId)
    await socket.sendAndWait(message: deleteStreamMessage, firstType: true)

    await self.socket.invalidate()
    self.publishStatus = .disconnected
  }

  private func handleStreamEvent(_ event: RTMPStreamEvent) async {
    switch event {
    case .publishStart:
      logger.debug("publishStart event received")
      publishStatus = .publishStart
      guard let configure = configure else { return }
      let metaMessage = MetaMessage(encodeType: encodeType, msgStreamId: connectId, meta: configure.metaData)
      await socket.send(message: metaMessage, firstType: true)

    case .pingRequest(let data):
      let message = UserControlMessage(type: .pingResponse, data: data, streamId: UInt16(connectId))
      await socket.send(message: message, firstType: true)

    case .playStart, .record, .pause:
      // Publisher doesn't need to handle these events
      break
    }
  }

  private func handleConnectionEvent(_ event: RTMPConnectionEvent) async {
    switch event {
    case .peerBandwidthChanged(let size):
      // send window ack message to server
      await socket.send(message: WindowAckMessage(size: size), firstType: true)

    case .statistics(let statistics):
      await delegate?.sessionTransmissionStatisticsChanged(self, statistics: statistics)

    case .disconnected:
      publishStatus = .disconnected
    }
  }
}


