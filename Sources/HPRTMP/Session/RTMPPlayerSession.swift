//
//  RTMPPlayerSession.swift
//
//
//  Created by 郭 輝平 on 2023/09/25.
//

import Foundation

public actor RTMPPlayerSession {
  // AsyncStreams for data flow; recreated on each play() to prevent old data leaking into new sessions
  public nonisolated(unsafe) private(set) var statusStream: AsyncStream<RTMPSessionStatus>
  public nonisolated(unsafe) private(set) var videoStream: AsyncStream<(Data, Int64)>
  public nonisolated(unsafe) private(set) var audioStream: AsyncStream<(Data, Int64)>
  public nonisolated(unsafe) private(set) var metaStream: AsyncStream<MetaDataResponse>
  public nonisolated(unsafe) private(set) var statisticsStream: AsyncStream<TransmissionStatistics>
  public nonisolated(unsafe) private(set) var logStream: AsyncStream<RTMPLogEvent>

  private var statusContinuation: AsyncStream<RTMPSessionStatus>.Continuation
  private var videoContinuation: AsyncStream<(Data, Int64)>.Continuation
  private var audioContinuation: AsyncStream<(Data, Int64)>.Continuation
  private var metaContinuation: AsyncStream<MetaDataResponse>.Continuation
  private var statisticsContinuation: AsyncStream<TransmissionStatistics>.Continuation
  private var logContinuation: AsyncStream<RTMPLogEvent>.Continuation

  public private(set) var status: RTMPSessionStatus = .unknown {
    didSet {
      statusContinuation.yield(status)
    }
  }

  private let encodeType: ObjectEncodingType = .amf0

  private var connection: RTMPConnection?

  private var streamId: MessageStreamId = .zero

  private var logger: RTMPLogger

  private var eventTasks: [Task<Void, Never>] = []

  // Using 4096 bytes (FFmpeg/OBS standard) for optimal compatibility and performance
  private static let defaultChunkSize: UInt32 = 4096


  public init() {
    (statusStream, statusContinuation) = AsyncStream.makeStream()
    (videoStream, videoContinuation) = AsyncStream.makeStream()
    (audioStream, audioContinuation) = AsyncStream.makeStream()
    (metaStream, metaContinuation) = AsyncStream.makeStream()
    (statisticsStream, statisticsContinuation) = AsyncStream.makeStream()
    (logStream, logContinuation) = AsyncStream.makeStream()
    self.logger = RTMPLogger(category: "PlayerSession", continuation: logContinuation)
  }

  deinit {
    statusContinuation.finish()
    videoContinuation.finish()
    audioContinuation.finish()
    metaContinuation.finish()
    statisticsContinuation.finish()
    logContinuation.finish()
  }

  private func resetStreams() {
    statusContinuation.finish()
    videoContinuation.finish()
    audioContinuation.finish()
    metaContinuation.finish()
    statisticsContinuation.finish()
    logContinuation.finish()

    (statusStream, statusContinuation) = AsyncStream.makeStream()
    (videoStream, videoContinuation) = AsyncStream.makeStream()
    (audioStream, audioContinuation) = AsyncStream.makeStream()
    (metaStream, metaContinuation) = AsyncStream.makeStream()
    (statisticsStream, statisticsContinuation) = AsyncStream.makeStream()
    (logStream, logContinuation) = AsyncStream.makeStream()
    logger = RTMPLogger(category: "PlayerSession", continuation: logContinuation)
  }

  public func play(url: String) async {
    // Reset streams to prevent old data leaking into new session (play -> stop -> play scenario)
    resetStreams()

    // Clean up existing connection if any
    if let connection = connection {
      await connection.invalidate()
    }

    // Cancel previous event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    connection = await RTMPConnection()
    guard let connection = connection else { return }

    // Forward connection log events to our log stream
    let logTask = Task { [connection, logContinuation] in
      for await event in connection.logEvents {
        logContinuation.yield(event)
      }
    }
    eventTasks.append(logTask)

    // Subscribe to media events
    let mediaTask = Task { [connection] in
      for await event in connection.mediaEvents {
        await handleMediaEvent(event)
      }
    }
    eventTasks.append(mediaTask)

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
      status = .handShakeStart
      try await connection.connect(url: url)
      status = .handShakeDone

      self.streamId = try await connection.createStream()
      status = .connect

      // Send play message
      let playMsg = PlayMessage(
        encodeType: encodeType,
        msgStreamId: streamId,
        streamName: await connection.urlInfo?.key ?? ""
      )
      await connection.send(message: playMsg, firstType: true)

      // Send chunk size
      let size = ChunkSizeMessage(size: Self.defaultChunkSize)
      await connection.send(message: size, firstType: true)
    } catch let rtmpError as RTMPError {
      status = .failed(err: rtmpError)
    } catch {
      let wrappedError = RTMPError.unknown(desc: error.localizedDescription)
      status = .failed(err: wrappedError)
    }
  }

  public func stop() async {
    // Cancel event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()

    guard let connection = connection else {
      status = .disconnected
      return
    }

    // send closeStream
    let closeStreamMessage = CloseStreamMessage(msgStreamId: streamId)
    await connection.sendAndWait(message: closeStreamMessage, firstType: true)

    // send deleteStream
    let deleteStreamMessage = DeleteStreamMessage(msgStreamId: streamId)
    await connection.sendAndWait(message: deleteStreamMessage, firstType: true)

    await connection.invalidate()
    self.connection = nil
    status = .disconnected
  }

  // MARK: - Event Handlers

  private func handleMediaEvent(_ event: RTMPMediaEvent) async {
    switch event {
    case .audio(let data, let timestamp):
      audioContinuation.yield((data, timestamp))

    case .video(let data, let timestamp):
      videoContinuation.yield((data, timestamp))

    case .metadata(let meta):
      metaContinuation.yield(meta)
    }
  }

  private func handleStreamEvent(_ event: RTMPStreamEvent) async {
    guard let connection = connection else { return }

    switch event {
    case .playStart:
      logger.debug("playStart event received")
      status = .playStart

    case .pingRequest(let data):
      let message = UserControlMessage(
        type: .pingResponse,
        data: data,
        streamId: ChunkStreamId(UInt16(streamId.value))
      )
      await connection.send(message: message, firstType: true)

    case .publishStart, .record, .pause:
      break
    }
  }

  private func handleConnectionEvent(_ event: RTMPConnectionEvent) async {
    guard let connection = connection else { return }

    switch event {
    case .peerBandwidthChanged(let size):
      await connection.send(message: WindowAckMessage(size: size), firstType: true)

    case .statistics(let statistics):
      statisticsContinuation.yield(statistics)

    case .disconnected:
      status = .disconnected
    }
  }
}
