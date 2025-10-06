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
      Task { [weak self] in
        guard let self = self else { return }
        await delegate?.sessionStatusChange(self, status: publishStatus)
      }
    }
  }
  
  public let encodeType: ObjectEncodingType = .amf0

  private var connection: RTMPConnection?
  
  private let transactionIdGenerator = TransactionIdGenerator()
  
  private var configure: PublishConfigure?

  private var streamId: MessageStreamId = .zero

  private let logger = Logger(subsystem: "HPRTMP", category: "Publish")

  private var eventTasks: [Task<Void, Never>] = []

  public init() {}
  
  public func publish(url: String, configure: PublishConfigure) async {
    self.configure = configure

    // Reset media header flags
    videoHeaderSended = false
    audioHeaderSended = false

    if let connection = connection {
      await connection.invalidate()
    }

    // Cancel previous event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    connection = await RTMPConnection()
    guard let connection = connection else { return }

    // Subscribe to stream events
    let streamTask = Task { [connection] in
      for await event in connection.streamEvents {
        await handleStreamEvent(event)
      }
    }
    eventTasks.append(streamTask)

    // Subscribe to connection events
    let connectionTask = Task { [connection] in
      for await event in connection.connectionEvents {
        await handleConnectionEvent(event)
      }
    }
    eventTasks.append(connectionTask)

    do {
      publishStatus = .handShakeStart
      try await connection.connect(url: url)
      publishStatus = .handShakeDone

      let streamId = try await connection.createStream()
      self.streamId = streamId
      publishStatus = .connect

      // Send publish message
      let publishMsg = PublishMessage(encodeType: encodeType, streamName: await connection.urlInfo?.key ?? "", type: .live, msgStreamId: streamId)
      await connection.send(message: publishMsg, firstType: true)

      // Send chunk size
      let chunkSize: UInt32 = 128 * 6
      let size = ChunkSizeMessage(size: chunkSize)
      await connection.send(message: size, firstType: true)
    } catch let rtmpError as RTMPError {
      publishStatus = .failed(err: rtmpError)
      await delegate?.sessionError(self, error: rtmpError)
    } catch {
      let wrappedError = RTMPError.uknown(desc: error.localizedDescription)
      publishStatus = .failed(err: wrappedError)
      await delegate?.sessionError(self, error: wrappedError)
    }
  }
  
  private var videoHeaderSended = false
  private var audioHeaderSended = false

  private enum MediaType {
    case video
    case audio
  }

  public func publishVideoHeader(data: Data) async {
    await publishMediaHeader(data: data, type: .video)
  }

  public func publishVideo(data: Data, delta: UInt32) async {
    await publishMediaData(data: data, delta: delta, type: .video, headerSent: videoHeaderSended)
  }

  public func publishAudioHeader(data: Data) async {
    await publishMediaHeader(data: data, type: .audio)
  }

  public func publishAudio(data: Data, delta: UInt32) async {
    await publishMediaData(data: data, delta: delta, type: .audio, headerSent: audioHeaderSended)
  }

  private func publishMediaHeader(data: Data, type: MediaType) async {
    guard let connection = connection else { return }

    let message: any RTMPMessage
    switch type {
    case .video:
      message = VideoMessage(data: data, msgStreamId: streamId, timestamp: .zero)
      videoHeaderSended = true
    case .audio:
      message = AudioMessage(data: data, msgStreamId: streamId, timestamp: .zero)
      audioHeaderSended = true
    }

    await connection.send(message: message, firstType: true)
  }

  private func publishMediaData(data: Data, delta: UInt32, type: MediaType, headerSent: Bool) async {
    guard headerSent, let connection = connection else { return }

    let message: any RTMPMessage
    switch type {
    case .video:
      message = VideoMessage(data: data, msgStreamId: streamId, timestamp: Timestamp(delta))
    case .audio:
      message = AudioMessage(data: data, msgStreamId: streamId, timestamp: Timestamp(delta))
    }

    await connection.send(message: message, firstType: false)
  }
  
  public func invalidate() async {
    // Cancel event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    guard let connection = connection else {
      self.publishStatus = .disconnected
      return
    }

    // send closeStream
    let closeStreamMessage = CloseStreamMessage(msgStreamId: streamId)
    await connection.send(message: closeStreamMessage, firstType: true)

    // send deleteStream and wait for it to be sent
    let deleteStreamMessage = DeleteStreamMessage(msgStreamId: streamId)
    await connection.sendAndWait(message: deleteStreamMessage, firstType: true)

    await connection.invalidate()

    // Reset media header flags
    videoHeaderSended = false
    audioHeaderSended = false

    self.publishStatus = .disconnected
  }

  private func handleStreamEvent(_ event: RTMPStreamEvent) async {
    guard let connection = connection else { return }

    switch event {
    case .publishStart:
      logger.debug("publishStart event received")
      publishStatus = .publishStart
      guard let configure = configure else { return }
      let metaMessage = MetaMessage(encodeType: encodeType, msgStreamId: streamId, meta: configure.metaData)
      await connection.send(message: metaMessage, firstType: true)

    case .pingRequest(let data):
      let message = UserControlMessage(type: .pingResponse, data: data, streamId: ChunkStreamId(UInt16(streamId.value)))
      await connection.send(message: message, firstType: true)

    case .playStart, .record, .pause:
      // Publisher doesn't need to handle these events
      break
    }
  }

  private func handleConnectionEvent(_ event: RTMPConnectionEvent) async {
    guard let connection = connection else { return }

    switch event {
    case .peerBandwidthChanged(let size):
      // send window ack message to server
      await connection.send(message: WindowAckMessage(size: size), firstType: true)

    case .statistics(let statistics):
      await delegate?.sessionTransmissionStatisticsChanged(self, statistics: statistics)

    case .disconnected:
      publishStatus = .disconnected
    }
  }
}


