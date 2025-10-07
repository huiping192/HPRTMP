//
//  RTMPPlayerSession.swift
//  
//
//  Created by 郭 輝平 on 2023/09/25.
//

import Foundation
import os

public actor RTMPPlayerSession {
  public enum Status: Equatable, Sendable {
    case unknown
    case handShakeStart
    case handShakeDone
    case connect
    case playStart
    case failed(err: RTMPError)
    case disconnected

    public static func ==(lhs: Status, rhs: Status) -> Bool {
      switch (lhs, rhs) {
      case (.unknown, .unknown),
        (.connect, .connect),
        (.playStart, .playStart),
        (.disconnected, .disconnected):
        return true
      case let (.failed(err1), .failed(err2)):
        return err1.localizedDescription == err2.localizedDescription
      default:
        return false
      }
    }
  }

  // AsyncStreams for data flow
  public let statusStream: AsyncStream<Status>
  public let errorStream: AsyncStream<RTMPError>
  public let videoStream: AsyncStream<(Data, Int64)>
  public let audioStream: AsyncStream<(Data, Int64)>
  public let metaStream: AsyncStream<MetaDataResponse>
  public let statisticsStream: AsyncStream<TransmissionStatistics>

  // Continuations for sending data
  private let statusContinuation: AsyncStream<Status>.Continuation
  private let errorContinuation: AsyncStream<RTMPError>.Continuation
  private let videoContinuation: AsyncStream<(Data, Int64)>.Continuation
  private let audioContinuation: AsyncStream<(Data, Int64)>.Continuation
  private let metaContinuation: AsyncStream<MetaDataResponse>.Continuation
  private let statisticsContinuation: AsyncStream<TransmissionStatistics>.Continuation

  public private(set) var status: Status = .unknown
  
  private func updateStatus(_ newStatus: Status) {
    status = newStatus
    statusContinuation.yield(newStatus)
  }
  
  private let encodeType: ObjectEncodingType = .amf0
  
  private var connection: RTMPConnection?
  
  private var streamId: MessageStreamId = .zero
  
  private let logger = Logger(subsystem: "HPRTMP", category: "Player")
  
  private var eventTasks: [Task<Void, Never>] = []


  public init() {
    // Initialize AsyncStreams and their continuations
    var statusCont: AsyncStream<Status>.Continuation!
    statusStream = AsyncStream { continuation in
      statusCont = continuation
    }
    statusContinuation = statusCont

    var errorCont: AsyncStream<RTMPError>.Continuation!
    errorStream = AsyncStream { continuation in
      errorCont = continuation
    }
    errorContinuation = errorCont

    var videoCont: AsyncStream<(Data, Int64)>.Continuation!
    videoStream = AsyncStream { continuation in
      videoCont = continuation
    }
    videoContinuation = videoCont

    var audioCont: AsyncStream<(Data, Int64)>.Continuation!
    audioStream = AsyncStream { continuation in
      audioCont = continuation
    }
    audioContinuation = audioCont

    var metaCont: AsyncStream<MetaDataResponse>.Continuation!
    metaStream = AsyncStream { continuation in
      metaCont = continuation
    }
    metaContinuation = metaCont

    var statisticsCont: AsyncStream<TransmissionStatistics>.Continuation!
    statisticsStream = AsyncStream { continuation in
      statisticsCont = continuation
    }
    statisticsContinuation = statisticsCont
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
      updateStatus(.handShakeStart)
      try await connection.connect(url: url)
      updateStatus(.handShakeDone)
      
      self.streamId = try await connection.createStream()
      updateStatus(.connect)
      
      // Send play message
      let playMsg = PlayMessage(
        encodeType: encodeType,
        msgStreamId: streamId,
        streamName: await connection.urlInfo?.key ?? ""
      )
      await connection.send(message: playMsg, firstType: true)
      
      // Send chunk size
      let chunkSize: UInt32 = 128 * 60
      let size = ChunkSizeMessage(size: chunkSize)
      await connection.send(message: size, firstType: true)
    } catch let rtmpError as RTMPError {
      updateStatus(.failed(err: rtmpError))
      errorContinuation.yield(rtmpError)
    } catch {
      let wrappedError = RTMPError.uknown(desc: error.localizedDescription)
      updateStatus(.failed(err: wrappedError))
      errorContinuation.yield(wrappedError)
    }
  }
  
 
  public func invalidate() async {
    // Cancel event tasks
    eventTasks.forEach { $0.cancel() }
    eventTasks.removeAll()
    
    guard let connection = connection else {
      updateStatus(.disconnected)
      return
    }
    
    // send closeStream
    let closeStreamMessage = CloseStreamMessage(encodeType: encodeType, msgStreamId: streamId)
    await connection.sendAndWait(message: closeStreamMessage, firstType: true)

    // send deleteStream
    let deleteStreamMessage = DeleteStreamMessage(encodeType: encodeType, msgStreamId: streamId)
    await connection.sendAndWait(message: deleteStreamMessage, firstType: true)

    await connection.invalidate()
    updateStatus(.disconnected)

    // Finish all continuations
    statusContinuation.finish()
    errorContinuation.finish()
    videoContinuation.finish()
    audioContinuation.finish()
    metaContinuation.finish()
    statisticsContinuation.finish()
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
      updateStatus(.playStart)
      
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
      updateStatus(.disconnected)
    }
  }
}

