//
//  RTMPMultiPublishSessionTests.swift
//  HPRTMPTests
//
//  Created by Huiping Guo on 2025/03/08.
//

import XCTest
@testable import HPRTMP

final class RTMPMultiPublishSessionTests: XCTestCase {

  // MARK: - Test Lifecycle

  override func setUpWithError() throws {
    // Setup code
  }

  override func tearDownWithError() throws {
    // Teardown code
  }

  // MARK: - Basic Functionality Tests

  func testInitialStateIsIdle() async throws {
    let session = RTMPMultiPublishSession()

    // Give some time for the initial status to be emitted
    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

    // Collect first status from stream
    let status = await withTimeout(seconds: 1) { @Sendable in
      var result: MultiPublishStatus?
      for await status in await session.statusStream {
        result = status
        break
      }
      return result
    }

    XCTAssertNotNil(status)
    XCTAssertEqual(status?.overallStatus, .stopped)
  }

  func testAddDestination() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "test-dest-1",
      url: "rtmp://localhost/live/stream1",
      configure: PublishConfigure(
        width: 1280,
        height: 720,
        videocodecid: 7, // AVC
        audiocodecid: 10, // AAC
        framerate: 30
      )
    )

    let destStatus = await session.status(for: "test-dest-1")
    XCTAssertNotNil(destStatus)
    XCTAssertEqual(destStatus?.id, "test-dest-1")
    XCTAssertEqual(destStatus?.url, "rtmp://localhost/live/stream1")
  }

  func testAddMultipleDestinations() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-1",
      url: "rtmp://server1.com/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    await session.addDestination(
      id: "dest-2",
      url: "rtmp://server2.com/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    let status1 = await session.status(for: "dest-1")
    let status2 = await session.status(for: "dest-2")

    XCTAssertNotNil(status1)
    XCTAssertNotNil(status2)
    XCTAssertEqual(status1?.url, "rtmp://server1.com/live/stream")
    XCTAssertEqual(status2?.url, "rtmp://server2.com/live/stream")
  }

  func testRemoveDestination() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-to-remove",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // Verify it exists
    var status = await session.status(for: "dest-to-remove")
    XCTAssertNotNil(status)

    // Remove
    await session.removeDestination(id: "dest-to-remove")

    // Verify it's gone
    status = await session.status(for: "dest-to-remove")
    XCTAssertNil(status)
  }

  func testDuplicateDestinationIdIsIgnored() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "duplicate-test",
      url: "rtmp://localhost/first",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // Try to add another with same ID
    await session.addDestination(
      id: "duplicate-test",
      url: "rtmp://localhost/second",
      configure: PublishConfigure(width: 1920, height: 1080, videocodecid: 7, audiocodecid: 10, framerate: 60)
    )

    // Should still have the first one
    let status = await session.status(for: "duplicate-test")
    XCTAssertEqual(status?.url, "rtmp://localhost/first")
  }

  // MARK: - Publishing Tests

  func testPublishVideoHeader() async throws {
    let session = RTMPMultiPublishSession()

    // Add a destination but don't start
    await session.addDestination(
      id: "dest-1",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // This should not throw
    let videoHeader = Data([0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x1F]) // SPS
    await session.publishVideoHeader(data: videoHeader)
  }

  func testPublishAudioHeader() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-1",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    let audioHeader = Data([0xAF, 0x90]) // AAC config
    await session.publishAudioHeader(data: audioHeader)
  }

  func testPublishVideoFrame() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-1",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // Send header first
    let videoHeader = Data([0x00, 0x00, 0x00, 0x01, 0x67])
    await session.publishVideoHeader(data: videoHeader)

    // Send frame
    let videoFrame = Data([0x00, 0x01, 0x02, 0x03])
    await session.publishVideo(data: videoFrame, delta: 33)
  }

  func testPublishAudioFrame() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-1",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // Send header first
    let audioHeader = Data([0xAF, 0x90])
    await session.publishAudioHeader(data: audioHeader)

    // Send frame
    let audioFrame = Data([0x00, 0x01, 0x02, 0x03, 0x04])
    await session.publishAudio(data: audioFrame, delta: 23)
  }

  // MARK: - Status Tests

  func testStopWithoutStart() async throws {
    let session = RTMPMultiPublishSession()

    await session.addDestination(
      id: "dest-1",
      url: "rtmp://localhost/live/stream",
      configure: PublishConfigure(width: 1280, height: 720, videocodecid: 7, audiocodecid: 10, framerate: 30)
    )

    // Stop should handle gracefully without start
    await session.stop()
  }

  // MARK: - RetryConfiguration Tests

  func testRetryConfigurationDefaultValues() {
    let retryConfig = RetryConfiguration.default

    XCTAssertEqual(retryConfig.maxRetries, 3)
    XCTAssertEqual(retryConfig.initialDelayMs, 1000)
    XCTAssertEqual(retryConfig.maxDelayMs, 30000)
    XCTAssertEqual(retryConfig.backoffMultiplier, 2.0)
  }

  func testRetryConfigurationDelayCalculation() {
    let retryConfig = RetryConfiguration(
      maxRetries: 5,
      initialDelayMs: 1000,
      maxDelayMs: 30000,
      backoffMultiplier: 2.0
    )

    // First retry: 1000 * 2^0 = 1000
    XCTAssertEqual(retryConfig.delayForRetry(0), 1000)

    // Second retry: 1000 * 2^1 = 2000
    XCTAssertEqual(retryConfig.delayForRetry(1), 2000)

    // Third retry: 1000 * 2^2 = 4000
    XCTAssertEqual(retryConfig.delayForRetry(2), 4000)

    // Fourth retry: 1000 * 2^3 = 8000
    XCTAssertEqual(retryConfig.delayForRetry(3), 8000)

    // Fifth retry: 1000 * 2^4 = 16000
    XCTAssertEqual(retryConfig.delayForRetry(4), 16000)

    // Sixth retry would exceed max, should be capped
    XCTAssertEqual(retryConfig.delayForRetry(5), 30000)
  }

  // MARK: - MultiPublishStatus Tests

  func testMultiPublishStatusCreation() {
    let destStatus = DestinationStatus(
      id: "test",
      url: "rtmp://localhost/live",
      sessionStatus: .publishStart,
      isConnected: true,
      error: nil,
      retryCount: 0
    )

    let status = MultiPublishStatus(
      overallStatus: .active,
      destinations: ["test": destStatus]
    )

    XCTAssertEqual(status.overallStatus, .active)
    XCTAssertEqual(status.destinations.count, 1)
    XCTAssertEqual(status.destinations["test"]?.id, "test")
  }

  // MARK: - Helper

  private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T?) async -> T? {
    return await withTaskGroup(of: T?.self) { group in
      group.addTask { @Sendable in
        await operation()
      }

      group.addTask { @Sendable in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }

      // Wait for first result
      for await result in group {
        // Cancel remaining tasks
        group.cancelAll()
        return result
      }
      return nil
    }
  }
}
