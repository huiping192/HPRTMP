//
//  RTMPMediaEventTests.swift
//
//  Created by Huiping Guo on 2026/03/11.
//

import XCTest
@testable import HPRTMP

final class RTMPMediaEventTests: XCTestCase {

  // MARK: - RTMPMediaEvent Tests

  func testAudioEventContainsCorrectData() {
    let testData = Data([0x01, 0x02, 0x03])
    let timestamp: Int64 = 1000
    
    let event = RTMPMediaEvent.audio(data: testData, timestamp: timestamp)
    
    if case .audio(let data, let ts) = event {
      XCTAssertEqual(data, testData)
      XCTAssertEqual(ts, timestamp)
    } else {
      XCTFail("Expected audio event")
    }
  }

  func testVideoEventContainsCorrectData() {
    let testData = Data([0x17, 0x01]) // AVC NALU
    let timestamp: Int64 = 2000
    
    let event = RTMPMediaEvent.video(data: testData, timestamp: timestamp)
    
    if case .video(let data, let ts) = event {
      XCTAssertEqual(data, testData)
      XCTAssertEqual(ts, timestamp)
    } else {
      XCTFail("Expected video event")
    }
  }

  func testMetadataEventWithValidData() {
    // Create a valid commandObject with required fields
    let metadata = MetaDataResponse(commandObject: ["duration": .double(10.0)])
    XCTAssertNotNil(metadata)
    
    guard let meta = metadata else { return }
    let event = RTMPMediaEvent.metadata(meta)
    
    if case .metadata(let receivedMeta) = event {
      XCTAssertEqual(receivedMeta.duration, 10.0)
    } else {
      XCTFail("Expected metadata event")
    }
  }

  // MARK: - RTMPStreamEvent Tests

  func testPublishStartEvent() {
    let event = RTMPStreamEvent.publishStart
    
    if case .publishStart = event {
      // Success
    } else {
      XCTFail("Expected publishStart event")
    }
  }

  func testPlayStartEvent() {
    let event = RTMPStreamEvent.playStart
    
    if case .playStart = event {
      // Success
    } else {
      XCTFail("Expected playStart event")
    }
  }

  func testRecordEvent() {
    let event = RTMPStreamEvent.record
    
    if case .record = event {
      // Success
    } else {
      XCTFail("Expected record event")
    }
  }

  func testPauseEventWithTrue() {
    let event = RTMPStreamEvent.pause(true)
    
    if case .pause(let isPaused) = event {
      XCTAssertTrue(isPaused)
    } else {
      XCTFail("Expected pause event")
    }
  }

  func testPauseEventWithFalse() {
    let event = RTMPStreamEvent.pause(false)
    
    if case .pause(let isPaused) = event {
      XCTAssertFalse(isPaused)
    } else {
      XCTFail("Expected pause event")
    }
  }

  func testPingRequestEvent() {
    let pingData = Data([0x00, 0x00, 0x00, 0x01]) // 1ms timestamp
    let event = RTMPStreamEvent.pingRequest(pingData)
    
    if case .pingRequest(let data) = event {
      XCTAssertEqual(data, pingData)
    } else {
      XCTFail("Expected pingRequest event")
    }
  }

  // MARK: - RTMPConnectionEvent Tests

  func testPeerBandwidthChangedEvent() {
    let bandwidth: UInt32 = 2500000
    let event = RTMPConnectionEvent.peerBandwidthChanged(bandwidth)
    
    if case .peerBandwidthChanged(let size) = event {
      XCTAssertEqual(size, bandwidth)
    } else {
      XCTFail("Expected peerBandwidthChanged event")
    }
  }

  func testStatisticsEvent() {
    let stats = TransmissionStatistics(
      pendingMessageCount: 0,
      totalBytesReceived: 1000,
      totalBytesSent: 500,
      unacknowledgedBytes: 0,
      windowSize: 2500000,
      windowUtilization: 0.5,
      videoFramesSent: 100,
      videoKeyFramesSent: 10,
      audioFramesSent: 200,
      videoBytesSent: 50000,
      audioBytesSent: 10000,
      videoBitrate: 1000.0,
      audioBitrate: 128.0,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 1000,
      pendingVideoFrames: 0,
      pendingAudioFrames: 0,
      pendingOtherMessages: 0
    )
    let event = RTMPConnectionEvent.statistics(stats)
    
    if case .statistics(let receivedStats) = event {
      XCTAssertEqual(receivedStats.totalBytesReceived, 1000)
      XCTAssertEqual(receivedStats.totalBytesSent, 500)
      XCTAssertEqual(receivedStats.videoFramesSent, 100)
    } else {
      XCTFail("Expected statistics event")
    }
  }

  func testDisconnectedEvent() {
    let event = RTMPConnectionEvent.disconnected
    
    if case .disconnected = event {
      // Success
    } else {
      XCTFail("Expected disconnected event")
    }
  }

  // MARK: - Sendable Conformance Verification
  // These types are verified as Sendable at compile time by being used in async contexts.
  // The fact that this code compiles proves Sendable conformance.

  func testRTMPMediaEventIsSendable() async {
    let event = RTMPMediaEvent.audio(data: Data([0x01]), timestamp: 100)
    let task = Task.detached { () -> RTMPMediaEvent in
      return event
    }
    let result = await task.value
    XCTAssertNotNil(result)
  }

  func testRTMPStreamEventIsSendable() async {
    let event = RTMPStreamEvent.pingRequest(Data([0x00]))
    let task = Task.detached { () -> RTMPStreamEvent in
      return event
    }
    let result = await task.value
    XCTAssertNotNil(result)
  }

  func testRTMPConnectionEventIsSendable() async {
    let event = RTMPConnectionEvent.disconnected
    let task = Task.detached { () -> RTMPConnectionEvent in
      return event
    }
    let result = await task.value
    XCTAssertNotNil(result)
  }

  // MARK: - Edge Cases

  func testEmptyDataInAudioEvent() {
    let event = RTMPMediaEvent.audio(data: Data(), timestamp: 0)
    
    if case .audio(let data, let timestamp) = event {
      XCTAssertTrue(data.isEmpty)
      XCTAssertEqual(timestamp, 0)
    } else {
      XCTFail("Expected audio event")
    }
  }

  func testEmptyDataInVideoEvent() {
    let event = RTMPMediaEvent.video(data: Data(), timestamp: 0)
    
    if case .video(let data, let timestamp) = event {
      XCTAssertTrue(data.isEmpty)
      XCTAssertEqual(timestamp, 0)
    } else {
      XCTFail("Expected video event")
    }
  }

  func testMaxTimestampValue() {
    let maxTimestamp: Int64 = Int64.max
    let event = RTMPMediaEvent.video(data: Data([0x01]), timestamp: maxTimestamp)
    
    if case .video(_, let timestamp) = event {
      XCTAssertEqual(timestamp, maxTimestamp)
    } else {
      XCTFail("Expected video event")
    }
  }

  func testMaxBandwidthValue() {
    let maxBandwidth: UInt32 = UInt32.max
    let event = RTMPConnectionEvent.peerBandwidthChanged(maxBandwidth)
    
    if case .peerBandwidthChanged(let size) = event {
      XCTAssertEqual(size, maxBandwidth)
    } else {
      XCTFail("Expected peerBandwidthChanged event")
    }
  }

  func testNegativeTimestamp() {
    // Although rare, negative timestamps should be handled
    let timestamp: Int64 = -1000
    let event = RTMPMediaEvent.audio(data: Data([0x01]), timestamp: timestamp)
    
    if case .audio(_, let ts) = event {
      XCTAssertEqual(ts, -1000)
    } else {
      XCTFail("Expected audio event")
    }
  }
}
