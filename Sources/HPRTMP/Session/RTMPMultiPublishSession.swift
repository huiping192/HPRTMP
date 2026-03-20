//
//  RTMPMultiPublishSession.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/03/08.
//

import Foundation

/// Multi-publish RTMP session that broadcasts to multiple destinations
public actor RTMPMultiPublishSession {

  // MARK: - Public Properties

  /// Stream of aggregated status updates
  public let statusStream: AsyncStream<MultiPublishStatus>

  /// Stream of aggregated transmission statistics
  public let statisticsStream: AsyncStream<MultiPublishStatistics>

  // MARK: - Internal State

  private var destinations: [String: DestinationContext] = [:]

  // Cached media headers for new destinations
  private var videoHeader: Data?
  private var audioHeader: Data?

  // Last timestamps for gap filling
  private var lastVideoTimestamp: UInt32 = 0
  private var lastAudioTimestamp: UInt32 = 0

  // State management
  private var isStarted: Bool = false
  private var isStopping: Bool = false

  // AsyncStream continuations
  private let statusContinuation: AsyncStream<MultiPublishStatus>.Continuation
  private let statisticsContinuation: AsyncStream<MultiPublishStatistics>.Continuation

  private let logger = RTMPLogger(category: "MultiPublish")

  // MARK: - Initialization

  public init() {
    (statusStream, statusContinuation) = AsyncStream.makeStream()
    (statisticsStream, statisticsContinuation) = AsyncStream.makeStream()
    
    // Emit initial stopped status
    let initialStatus = MultiPublishStatus(
      overallStatus: .stopped,
      destinations: [:]
    )
    statusContinuation.yield(initialStatus)
  }

  deinit {
    statusContinuation.finish()
    statisticsContinuation.finish()
  }

  // MARK: - Public Methods

  /// Add a destination RTMP server
  public func addDestination(
    id: String,
    url: String,
    configure: PublishConfigure
  ) async {
    guard destinations[id] == nil else {
      logger.warning("Destination \(id) already exists")
      return
    }

    let config = DestinationConfig(id: id, url: url, configure: configure)
    let context = DestinationContext(config: config)

    // If we already have headers, send them to the new destination
    if isStarted {
      await context.sendHeadersIfAvailable(videoHeader: videoHeader, audioHeader: audioHeader)
      await context.startListening()
    }

    destinations[id] = context
    await updateStatus()
  }

  /// Remove a destination RTMP server
  public func removeDestination(id: String) async {
    guard let context = destinations[id] else {
      logger.warning("Destination \(id) not found")
      return
    }

    await context.stop()
    destinations.removeValue(forKey: id)
    await updateStatus()
  }

  /// Start publishing to all destinations
  public func start() async {
    guard !isStarted else {
      logger.warning("Already started")
      return
    }

    isStarted = true
    isStopping = false

    // Start all destinations
    for (_, context) in destinations {
      await context.start()
      await context.startListening()
    }

    await updateStatus()
  }

  /// Stop publishing to all destinations
  public func stop() async {
    guard isStarted else { return }

    isStopping = true

    // Stop all destinations
    for (_, context) in destinations {
      await context.stop()
    }

    isStarted = false
    isStopping = false

    // Clear cached headers
    videoHeader = nil
    audioHeader = nil
    lastVideoTimestamp = 0
    lastAudioTimestamp = 0

    await updateStatus()
  }

  /// Publish video header data to all destinations
  public func publishVideoHeader(data: Data) async {
    videoHeader = data
    await broadcastVideoHeader(data: data)
  }

  /// Publish video frame data to all destinations
  public func publishVideo(data: Data, delta: UInt32) async {
    lastVideoTimestamp = lastVideoTimestamp + delta
    await broadcastVideo(data: data, timestamp: lastVideoTimestamp)
  }

  /// Publish audio header data to all destinations
  public func publishAudioHeader(data: Data) async {
    audioHeader = data
    await broadcastAudioHeader(data: data)
  }

  /// Publish audio frame data to all destinations
  public func publishAudio(data: Data, delta: UInt32) async {
    lastAudioTimestamp = lastAudioTimestamp + delta
    await broadcastAudio(data: data, timestamp: lastAudioTimestamp)
  }

  /// Get status for a specific destination
  public func status(for id: String) async -> DestinationStatus? {
    guard let context = destinations[id] else { return nil }
    return await context.getStatus()
  }

  // MARK: - Private Methods

  private func updateStatus() async {
    var destinationStatuses: [String: DestinationStatus] = [:]

    for (id, context) in destinations {
      destinationStatuses[id] = await context.getStatus()
    }

    let overallStatus: OverallStatus
    if !isStarted {
      overallStatus = .stopped
    } else if isStopping {
      overallStatus = .stopping
    } else {
      let anyConnected = destinationStatuses.values.contains { $0.isConnected }
      overallStatus = anyConnected ? .active : .idle
    }

    let status = MultiPublishStatus(overallStatus: overallStatus, destinations: destinationStatuses)
    statusContinuation.yield(status)
  }

  private func broadcastVideoHeader(data: Data) async {
    await withTaskGroup(of: Void.self) { group in
      for (_, context) in destinations {
        group.addTask {
          await context.publishVideoHeader(data: data)
        }
      }
    }
  }

  private func broadcastAudioHeader(data: Data) async {
    await withTaskGroup(of: Void.self) { group in
      for (_, context) in destinations {
        group.addTask {
          await context.publishAudioHeader(data: data)
        }
      }
    }
  }

  private func broadcastVideo(data: Data, timestamp: UInt32) async {
    await withTaskGroup(of: Void.self) { group in
      for (_, context) in destinations {
        group.addTask {
          await context.publishVideo(data: data, timestamp: timestamp)
        }
      }
    }
  }

  private func broadcastAudio(data: Data, timestamp: UInt32) async {
    await withTaskGroup(of: Void.self) { group in
      for (_, context) in destinations {
        group.addTask {
          await context.publishAudio(data: data, timestamp: timestamp)
        }
      }
    }
  }

  private func collectStatistics() async -> MultiPublishStatistics {
    var destStats: [String: TransmissionStatistics] = [:]

    for (id, context) in destinations {
      if let stats = await context.getStatistics() {
        destStats[id] = stats
      }
    }

    return MultiPublishStatistics(timestamp: Date(), destinations: destStats)
  }
}

// MARK: - DestinationContext

/// Internal actor managing a single destination's RTMP session
actor DestinationContext {
  let config: DestinationConfig
  var session: RTMPPublishSession?
  var retryConfig: RetryConfiguration = .default

  var retryCount: Int = 0
  var isStopping: Bool = false

  private var _currentStatus: DestinationStatus
  private var _currentStatistics: TransmissionStatistics?

  private var statusTask: Task<Void, Never>?
  private var statisticsTask: Task<Void, Never>?
  private var retryTask: Task<Void, Never>?

  // MARK: - Accessors

  func getStatus() -> DestinationStatus {
    _currentStatus
  }

  func getStatistics() -> TransmissionStatistics? {
    _currentStatistics
  }

  // MARK: - Initialization

  init(config: DestinationConfig) {
    self.config = config
    self._currentStatus = DestinationStatus(
      id: config.id,
      url: config.url,
      sessionStatus: .unknown,
      isConnected: false,
      error: nil,
      retryCount: 0
    )
  }

  // MARK: - Public Methods

  func start() async {
    session = RTMPPublishSession()

    guard let session = session else { return }

    await session.publish(url: config.url, configure: config.configure)
  }

  func stop() async {
    isStopping = true
    retryTask?.cancel()
    statusTask?.cancel()
    statisticsTask?.cancel()

    if let session = session {
      await session.stop()
    }

    session = nil
    isStopping = false
  }

  func startListening() async {
    guard let session = session else { return }

    // Listen to status changes
    statusTask = Task { [weak self] in
      guard let self = self else { return }
      for await sessionStatus in session.statusStream {
        await self.handleStatusChange(sessionStatus)
      }
    }

    // Listen to statistics
    statisticsTask = Task { [weak self] in
      guard let self = self else { return }
      for await stats in session.statisticsStream {
        await self.handleStatistics(stats)
      }
    }
  }

  func sendHeadersIfAvailable(videoHeader: Data?, audioHeader: Data?) async {
    guard let session = session else { return }

    if let videoHeader = videoHeader {
      await session.publishVideoHeader(data: videoHeader)
    }

    if let audioHeader = audioHeader {
      await session.publishAudioHeader(data: audioHeader)
    }
  }

  func publishVideoHeader(data: Data) async {
    guard let session = session else { return }
    await session.publishVideoHeader(data: data)
  }

  func publishAudioHeader(data: Data) async {
    guard let session = session else { return }
    await session.publishAudioHeader(data: data)
  }

  func publishVideo(data: Data, timestamp: UInt32) async {
    guard let session = session else { return }
    await session.publishVideo(data: data, timestamp: timestamp)
  }

  func publishAudio(data: Data, timestamp: UInt32) async {
    guard let session = session else { return }
    await session.publishAudio(data: data, timestamp: timestamp)
  }

  // MARK: - Private Methods

  private func handleStatusChange(_ newStatus: RTMPSessionStatus) async {
    switch newStatus {
    case .publishStart:
      _currentStatus = DestinationStatus(
        id: config.id,
        url: config.url,
        sessionStatus: newStatus,
        isConnected: true,
        error: nil,
        retryCount: retryCount
      )
      retryCount = 0

    case .disconnected:
      _currentStatus = DestinationStatus(
        id: config.id,
        url: config.url,
        sessionStatus: newStatus,
        isConnected: false,
        error: nil,
        retryCount: retryCount
      )

      if !isStopping {
        await attemptRetry()
      }

    case .failed(let err):
      _currentStatus = DestinationStatus(
        id: config.id,
        url: config.url,
        sessionStatus: newStatus,
        isConnected: false,
        error: err,
        retryCount: retryCount
      )

      if !isStopping {
        await attemptRetry()
      }

    default:
      _currentStatus = DestinationStatus(
        id: config.id,
        url: config.url,
        sessionStatus: newStatus,
        isConnected: _currentStatus.isConnected,
        error: _currentStatus.error,
        retryCount: retryCount
      )
    }
  }

  private func handleStatistics(_ stats: TransmissionStatistics) async {
    _currentStatistics = stats
  }

  private func attemptRetry() async {
    guard retryCount < retryConfig.maxRetries else {
      return
    }

    let delay = retryConfig.delayForRetry(retryCount)
    retryCount += 1

    _currentStatus = DestinationStatus(
      id: config.id,
      url: config.url,
      sessionStatus: _currentStatus.sessionStatus,
      isConnected: false,
      error: _currentStatus.error,
      retryCount: retryCount
    )

    // Wait before retry
    try? await Task.sleep(nanoseconds: delay * 1_000_000)

    guard !Task.isCancelled, !isStopping else { return }

    // Reconnect
    await reconnect()
  }

  private func reconnect() async {
    statusTask?.cancel()
    statisticsTask?.cancel()

    session = nil
    session = RTMPPublishSession()

    guard let session = session else { return }

    await session.publish(url: config.url, configure: config.configure)
    await startListening()
  }
}
