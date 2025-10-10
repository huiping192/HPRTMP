//
//  RTMPPlayerSession.swift
//  
//
//  Created by 郭 輝平 on 2023/09/25.
//

import Foundation
import os

public actor RTMPPlayerSession {
  // AsyncStreams for data flow
  public let statusStream: AsyncStream<RTMPSessionStatus>
  public let videoStream: AsyncStream<(Data, Int64)>
  public let audioStream: AsyncStream<(Data, Int64)>
  public let metaStream: AsyncStream<MetaDataResponse>
  public let statisticsStream: AsyncStream<TransmissionStatistics>

  // Continuations for sending data
  private let statusContinuation: AsyncStream<RTMPSessionStatus>.Continuation
  private let videoContinuation: AsyncStream<(Data, Int64)>.Continuation
  private let audioContinuation: AsyncStream<(Data, Int64)>.Continuation
  private let metaContinuation: AsyncStream<MetaDataResponse>.Continuation
  private let statisticsContinuation: AsyncStream<TransmissionStatistics>.Continuation

  public private(set) var status: RTMPSessionStatus = .unknown {
    didSet {
      statusContinuation.yield(status)
    }
  }
  
  private let encodeType: ObjectEncodingType = .amf0
  
  private var connection: RTMPConnection?
  
  private var streamId: MessageStreamId = .zero
  
  private let logger = Logger(subsystem: "HPRTMP", category: "Player")

  private var eventTasks: [Task<Void, Never>] = []

  // RTMP chunk size configuration
  // Using 4096 bytes (FFmpeg/OBS standard) for optimal compatibility and performance
  private static let defaultChunkSize: UInt32 = 4096


  public init() {
    // Initialize AsyncStreams and their continuations using makeStream()
    (statusStream, statusContinuation) = AsyncStream.makeStream()
    (videoStream, videoContinuation) = AsyncStream.makeStream()
    (audioStream, audioContinuation) = AsyncStream.makeStream()
    (metaStream, metaContinuation) = AsyncStream.makeStream()
    (statisticsStream, statisticsContinuation) = AsyncStream.makeStream()
  }

  deinit {
    statusContinuation.finish()
    videoContinuation.finish()
    audioContinuation.finish()
    metaContinuation.finish()
    statisticsContinuation.finish()
  }

  public func play(url: String) async {
    // Clean up existing connection if any
    if let connection = connection {
      await connection.invalidate()
    }
    
    // Cancel previous event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()
    
    connection = await RTMPConnection()
    guard let connection = connection else { return }
    
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

    // Note: continuations are finished in deinit to support session reuse
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
      // Player doesn't need to handle these events
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
      statisticsContinuation.yield(statistics)

    case .disconnected:
      status = .disconnected
    }
  }
}

