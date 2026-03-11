//
//  RTMPPublishSessionTests.swift
//  HPRTMPTests
//
//  Tests for RTMPPublishSession actor
//

import XCTest
@testable import HPRTMP

final class RTMPPublishSessionTests: XCTestCase {

  // MARK: - Test Lifecycle

  override func setUpWithError() throws {
    // Setup code
  }

  override func tearDownWithError() throws {
    // Teardown code
  }

  // MARK: - Initial State Tests

  func testInitialStatusIsUnknown() async throws {
    let session = RTMPPublishSession()

    // Get the initial status directly from publishStatus property
    let status = await session.publishStatus

    XCTAssertEqual(status, .unknown)
  }

  // MARK: - Timestamp Overflow Protection Tests

  /// Test that video timestamp wrapping works correctly
  func testVideoTimestampWrapping() async throws {
    // Simulate timestamps that would overflow UInt32
    // Starting near max value
    let largeDelta: UInt32 = 100

    // Directly test the wrapping behavior by checking the logic
    // Note: We can't actually publish without a real connection, but we can verify
    // the wrapping operation directly
    let maxValue: UInt32 = UInt32.max
    let initialTimestamp = Timestamp(maxValue - 50)
    let wrappedTimestamp = Timestamp(initialTimestamp.value &+ largeDelta)

    // After wrapping: (max - 50) + 100 = 49 (wraps around)
    XCTAssertEqual(wrappedTimestamp.value, 49)
  }

  /// Test that audio timestamp wrapping works correctly
  func testAudioTimestampWrapping() async throws {
    // Test audio timestamp wrapping similar to video
    let maxValue: UInt32 = UInt32.max
    let largeDelta: UInt32 = 200
    let initialTimestamp = Timestamp(maxValue - 100)
    let wrappedTimestamp = Timestamp(initialTimestamp.value &+ largeDelta)

    // After wrapping: (max - 100) + 200 = 99 (wraps around)
    XCTAssertEqual(wrappedTimestamp.value, 99)
  }

  /// Test timestamp wrapping at exactly max value
  func testTimestampWrappingAtMax() async throws {
    let maxValue: UInt32 = UInt32.max
    let initialTimestamp = Timestamp(maxValue)
    let delta: UInt32 = 1

    let wrappedTimestamp = Timestamp(initialTimestamp.value &+ delta)

    // Should wrap to 0
    XCTAssertEqual(wrappedTimestamp.value, 0)
  }

  /// Test timestamp wrapping with multiple wraps
  func testTimestampMultipleWraps() async throws {
    let initialValue: UInt32 = UInt32.max - 10
    let delta1: UInt32 = 5
    let delta2: UInt32 = 10

    // First wrap: (max - 10) + 5 = max - 5
    var timestamp = Timestamp(initialValue)
    timestamp = Timestamp(timestamp.value &+ delta1)
    XCTAssertEqual(timestamp.value, UInt32.max - 5)

    // Second wrap: (max - 5) + 10 = 4 (wraps around)
    timestamp = Timestamp(timestamp.value &+ delta2)
    XCTAssertEqual(timestamp.value, 4)
  }

  // MARK: - Stop Tests

  func testStopWithoutStart() async throws {
    let session = RTMPPublishSession()

    // Stop without starting should set status to disconnected
    await session.stop()

    // Give some time for status update
    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

    let status = await session.publishStatus
    XCTAssertEqual(status, .disconnected)
  }

  // MARK: - Publish Configuration Tests

  func testPublishConfigurationCreation() throws {
    let configure = PublishConfigure(
      width: 1920,
      height: 1080,
      videocodecid: 7, // AVC
      audiocodecid: 10, // AAC
      framerate: 30,
      videoDatarate: 5000,
      audioDatarate: 128,
      audioSamplerate: 44100
    )

    XCTAssertEqual(configure.width, 1920)
    XCTAssertEqual(configure.height, 1080)
    XCTAssertEqual(configure.videocodecid, 7)
    XCTAssertEqual(configure.audiocodecid, 10)
    XCTAssertEqual(configure.framerate, 30)
    XCTAssertEqual(configure.videoDatarate, 5000)
    XCTAssertEqual(configure.audioDatarate, 128)
    XCTAssertEqual(configure.audioSamplerate, 44100)
  }

  func testPublishConfigurationOptionalFields() throws {
    let configure = PublishConfigure(
      width: 1280,
      height: 720,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30
    )

    XCTAssertNil(configure.videoDatarate)
    XCTAssertNil(configure.audioDatarate)
    XCTAssertNil(configure.audioSamplerate)
  }

  func testPublishConfigurationMetadata() throws {
    let configure = PublishConfigure(
      width: 1280,
      height: 720,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30,
      videoDatarate: 4500,
      audioDatarate: 96
    )

    let metaData = configure.metaData

    XCTAssertEqual(metaData.width, 1280)
    XCTAssertEqual(metaData.height, 720)
    XCTAssertEqual(metaData.videocodecid, 7)
    XCTAssertEqual(metaData.audiocodecid, 10)
    XCTAssertEqual(metaData.framerate, 30)
    XCTAssertEqual(metaData.videodatarate, 4500)
    XCTAssertEqual(metaData.audiodatarate, 96)
  }
}
