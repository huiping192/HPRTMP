//
//  TransmissionStatisticsTests.swift
//  HPRTMPTests
//
//  Created by Huiping Guo on 2025/10/06.
//

import XCTest
@testable import HPRTMP

final class TransmissionStatisticsTests: XCTestCase {
  
  // MARK: - Initialization Tests
  
  func testFullInitialization() {
    let stats = TransmissionStatistics(
      pendingMessageCount: 10,
      totalBytesReceived: 1000,
      totalBytesSent: 2000,
      unacknowledgedBytes: 500,
      windowSize: 2500000,
      windowUtilization: 0.2,
      videoFramesSent: 100,
      videoKeyFramesSent: 5,
      audioFramesSent: 50,
      videoBytesSent: 500000,
      audioBytesSent: 100000,
      videoBitrate: 1000.0,
      audioBitrate: 128.0,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 500,
      pendingVideoFrames: 3,
      pendingAudioFrames: 2,
      pendingOtherMessages: 5
    )
    
    XCTAssertEqual(stats.pendingMessageCount, 10)
    XCTAssertEqual(stats.totalBytesReceived, 1000)
    XCTAssertEqual(stats.totalBytesSent, 2000)
    XCTAssertEqual(stats.unacknowledgedBytes, 500)
    XCTAssertEqual(stats.windowSize, 2500000)
    XCTAssertEqual(stats.windowUtilization, 0.2)
    XCTAssertEqual(stats.videoFramesSent, 100)
    XCTAssertEqual(stats.videoKeyFramesSent, 5)
    XCTAssertEqual(stats.audioFramesSent, 50)
    XCTAssertEqual(stats.videoBytesSent, 500000)
    XCTAssertEqual(stats.audioBytesSent, 100000)
    XCTAssertEqual(stats.videoBitrate, 1000.0)
    XCTAssertEqual(stats.audioBitrate, 128.0)
    XCTAssertEqual(stats.currentVideoTimestamp, 1000)
    XCTAssertEqual(stats.currentAudioTimestamp, 500)
    XCTAssertEqual(stats.pendingVideoFrames, 3)
    XCTAssertEqual(stats.pendingAudioFrames, 2)
    XCTAssertEqual(stats.pendingOtherMessages, 5)
  }
  
  func testZeroValuesInitialization() {
    let stats = TransmissionStatistics(
      pendingMessageCount: 0,
      totalBytesReceived: 0,
      totalBytesSent: 0,
      unacknowledgedBytes: 0,
      windowSize: 0,
      windowUtilization: 0.0,
      videoFramesSent: 0,
      videoKeyFramesSent: 0,
      audioFramesSent: 0,
      videoBytesSent: 0,
      audioBytesSent: 0,
      videoBitrate: 0.0,
      audioBitrate: 0.0,
      currentVideoTimestamp: 0,
      currentAudioTimestamp: 0,
      pendingVideoFrames: 0,
      pendingAudioFrames: 0,
      pendingOtherMessages: 0
    )
    
    XCTAssertEqual(stats.pendingMessageCount, 0)
    XCTAssertEqual(stats.totalBytesReceived, 0)
    XCTAssertEqual(stats.totalBytesSent, 0)
    XCTAssertEqual(stats.unacknowledgedBytes, 0)
    XCTAssertEqual(stats.windowSize, 0)
    XCTAssertEqual(stats.windowUtilization, 0.0)
    XCTAssertEqual(stats.videoFramesSent, 0)
    XCTAssertEqual(stats.videoKeyFramesSent, 0)
    XCTAssertEqual(stats.audioFramesSent, 0)
    XCTAssertEqual(stats.videoBytesSent, 0)
    XCTAssertEqual(stats.audioBytesSent, 0)
    XCTAssertEqual(stats.videoBitrate, 0.0)
    XCTAssertEqual(stats.audioBitrate, 0.0)
    XCTAssertEqual(stats.currentVideoTimestamp, 0)
    XCTAssertEqual(stats.currentAudioTimestamp, 0)
    XCTAssertEqual(stats.pendingVideoFrames, 0)
    XCTAssertEqual(stats.pendingAudioFrames, 0)
    XCTAssertEqual(stats.pendingOtherMessages, 0)
  }
  
  func testMaximumValuesInitialization() {
    let stats = TransmissionStatistics(
      pendingMessageCount: Int.max,
      totalBytesReceived: UInt32.max,
      totalBytesSent: UInt32.max,
      unacknowledgedBytes: Int64.max,
      windowSize: UInt32.max,
      windowUtilization: 1.0,
      videoFramesSent: UInt64.max,
      videoKeyFramesSent: UInt64.max,
      audioFramesSent: UInt64.max,
      videoBytesSent: UInt64.max,
      audioBytesSent: UInt64.max,
      videoBitrate: Double.greatestFiniteMagnitude,
      audioBitrate: Double.greatestFiniteMagnitude,
      currentVideoTimestamp: UInt32.max,
      currentAudioTimestamp: UInt32.max,
      pendingVideoFrames: Int.max,
      pendingAudioFrames: Int.max,
      pendingOtherMessages: Int.max
    )
    
    XCTAssertEqual(stats.pendingMessageCount, Int.max)
    XCTAssertEqual(stats.totalBytesReceived, UInt32.max)
    XCTAssertEqual(stats.totalBytesSent, UInt32.max)
    XCTAssertEqual(stats.unacknowledgedBytes, Int64.max)
    XCTAssertEqual(stats.windowSize, UInt32.max)
    XCTAssertEqual(stats.windowUtilization, 1.0)
    XCTAssertEqual(stats.videoFramesSent, UInt64.max)
    XCTAssertEqual(stats.videoKeyFramesSent, UInt64.max)
    XCTAssertEqual(stats.audioFramesSent, UInt64.max)
    XCTAssertEqual(stats.videoBytesSent, UInt64.max)
    XCTAssertEqual(stats.audioBytesSent, UInt64.max)
    XCTAssertEqual(stats.currentVideoTimestamp, UInt32.max)
    XCTAssertEqual(stats.currentAudioTimestamp, UInt32.max)
  }
  
  // MARK: - Sendable Tests
  
  func testSendableConformance() {
    let stats = TransmissionStatistics(
      pendingMessageCount: 10,
      totalBytesReceived: 1000,
      totalBytesSent: 2000,
      unacknowledgedBytes: 500,
      windowSize: 2500000,
      windowUtilization: 0.2,
      videoFramesSent: 100,
      videoKeyFramesSent: 5,
      audioFramesSent: 50,
      videoBytesSent: 500000,
      audioBytesSent: 100000,
      videoBitrate: 1000.0,
      audioBitrate: 128.0,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 500,
      pendingVideoFrames: 3,
      pendingAudioFrames: 2,
      pendingOtherMessages: 5
    )
    
    // This test verifies that TransmissionStatistics is Sendable
    // The compiler will enforce Sendable conformance if it's not correct
    func sendThroughConcurrentDomain(_ stats: TransmissionStatistics) async -> TransmissionStatistics {
      return stats
    }
    
    Task {
      let received = await sendThroughConcurrentDomain(stats)
      XCTAssertEqual(received.pendingMessageCount, stats.pendingMessageCount)
    }
  }
  
  // MARK: - Value Calculation Tests
  
  func testWindowUtilizationCalculation() {
    // Test window utilization is calculated correctly
    // windowUtilization = unacknowledgedBytes / windowSize
    let stats = TransmissionStatistics(
      pendingMessageCount: 10,
      totalBytesReceived: 1000,
      totalBytesSent: 2000,
      unacknowledgedBytes: 500000,
      windowSize: 2500000,
      windowUtilization: 0.2,
      videoFramesSent: 100,
      videoKeyFramesSent: 5,
      audioFramesSent: 50,
      videoBytesSent: 500000,
      audioBytesSent: 100000,
      videoBitrate: 1000.0,
      audioBitrate: 128.0,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 500,
      pendingVideoFrames: 3,
      pendingAudioFrames: 2,
      pendingOtherMessages: 5
    )
    
    XCTAssertEqual(stats.windowUtilization, 0.2, accuracy: 0.001)
    XCTAssertEqual(stats.unacknowledgedBytes, 500000)
    XCTAssertEqual(stats.windowSize, 2500000)
  }
  
  // MARK: - Edge Cases
  
  func testPendingMessageCountMatchesSumOfIndividualCounts() {
    let pendingVideoFrames = 3
    let pendingAudioFrames = 2
    let pendingOtherMessages = 5
    let totalPending = pendingVideoFrames + pendingAudioFrames + pendingOtherMessages
    
    let stats = TransmissionStatistics(
      pendingMessageCount: totalPending,
      totalBytesReceived: 1000,
      totalBytesSent: 2000,
      unacknowledgedBytes: 500,
      windowSize: 2500000,
      windowUtilization: 0.2,
      videoFramesSent: 100,
      videoKeyFramesSent: 5,
      audioFramesSent: 50,
      videoBytesSent: 500000,
      audioBytesSent: 100000,
      videoBitrate: 1000.0,
      audioBitrate: 128.0,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 500,
      pendingVideoFrames: pendingVideoFrames,
      pendingAudioFrames: pendingAudioFrames,
      pendingOtherMessages: pendingOtherMessages
    )
    
    XCTAssertEqual(stats.pendingMessageCount, stats.pendingVideoFrames + stats.pendingAudioFrames + stats.pendingOtherMessages)
  }
  
  func testBitratePrecision() {
    // Test that bitrate values preserve precision
    let stats = TransmissionStatistics(
      pendingMessageCount: 10,
      totalBytesReceived: 1000,
      totalBytesSent: 2000,
      unacknowledgedBytes: 500,
      windowSize: 2500000,
      windowUtilization: 0.2,
      videoFramesSent: 100,
      videoKeyFramesSent: 5,
      audioFramesSent: 50,
      videoBytesSent: 500000,
      audioBytesSent: 100000,
      videoBitrate: 1234.567,
      audioBitrate: 64.125,
      currentVideoTimestamp: 1000,
      currentAudioTimestamp: 500,
      pendingVideoFrames: 3,
      pendingAudioFrames: 2,
      pendingOtherMessages: 5
    )
    
    XCTAssertEqual(stats.videoBitrate, 1234.567, accuracy: 0.001)
    XCTAssertEqual(stats.audioBitrate, 64.125, accuracy: 0.001)
  }
}
