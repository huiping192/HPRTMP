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
    await socket.setDelegate(delegate: self)

    // Subscribe to stream events
    let streamTask = Task {
      for await event in await socket.streamEvents {
        await handleStreamEvent(event)
      }
    }
    eventTasks.append(streamTask)

    // Subscribe to connection events
    let connectionTask = Task {
      for await event in await socket.connectionEvents {
        await handleConnectionEvent(event)
      }
    }
    eventTasks.append(connectionTask)

    await socket.connect(url: url)

    publishStatus = .handShakeStart
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

extension RTMPPublishSession: RTMPSocketDelegate {
  func socketHandShakeDone(_ socket: RTMPSocket) {
    Task {
      publishStatus = .handShakeDone

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

  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int) {
    Task {
      publishStatus = .connect

      let message = await PublishMessage(encodeType: encodeType, streamName: socket.urlInfo?.key ?? "", type: .live, msgStreamId: msgStreamId)

      self.connectId = msgStreamId
      await socket.send(message: message, firstType: true)
    }
  }

  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    Task {
      await delegate?.sessionError(self, error: err)
    }
  }
}

