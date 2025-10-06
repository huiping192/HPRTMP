//
//  MediaStatisticsCollector.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

actor MediaStatisticsCollector {
  private var videoFramesSent: UInt64 = 0
  private var videoKeyFramesSent: UInt64 = 0
  private var audioFramesSent: UInt64 = 0

  private var videoBytesSent: UInt64 = 0
  private var audioBytesSent: UInt64 = 0

  private var currentVideoTimestamp: UInt32 = 0
  private var currentAudioTimestamp: UInt32 = 0

  private struct BitrateWindow {
    var bytes: UInt64 = 0
    var timestamp: TimeInterval

    init() {
      self.timestamp = Date().timeIntervalSince1970
    }
  }

  private var videoBitrateWindow = BitrateWindow()
  private var audioBitrateWindow = BitrateWindow()

  private let bitrateWindowDuration: TimeInterval = 1.0

  func recordVideoFrame(bytes: Int, timestamp: UInt32, isKeyFrame: Bool) {
    videoFramesSent += 1
    videoBytesSent += UInt64(bytes)
    currentVideoTimestamp = timestamp

    if isKeyFrame {
      videoKeyFramesSent += 1
    }
  }

  func recordAudioFrame(bytes: Int, timestamp: UInt32) {
    audioFramesSent += 1
    audioBytesSent += UInt64(bytes)
    currentAudioTimestamp = timestamp
  }

  func getStatistics() -> (
    videoFramesSent: UInt64,
    videoKeyFramesSent: UInt64,
    audioFramesSent: UInt64,
    videoBytesSent: UInt64,
    audioBytesSent: UInt64,
    videoBitrate: Double,
    audioBitrate: Double,
    currentVideoTimestamp: UInt32,
    currentAudioTimestamp: UInt32
  ) {
    let videoBitrate = calculateBitrate(
      currentBytes: videoBytesSent,
      window: &videoBitrateWindow
    )

    let audioBitrate = calculateBitrate(
      currentBytes: audioBytesSent,
      window: &audioBitrateWindow
    )

    return (
      videoFramesSent: videoFramesSent,
      videoKeyFramesSent: videoKeyFramesSent,
      audioFramesSent: audioFramesSent,
      videoBytesSent: videoBytesSent,
      audioBytesSent: audioBytesSent,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      currentVideoTimestamp: currentVideoTimestamp,
      currentAudioTimestamp: currentAudioTimestamp
    )
  }

  private func calculateBitrate(
    currentBytes: UInt64,
    window: inout BitrateWindow
  ) -> Double {
    let now = Date().timeIntervalSince1970
    let elapsed = now - window.timestamp

    guard elapsed >= bitrateWindowDuration else {
      return 0.0
    }

    let bytesSinceLast = currentBytes - window.bytes
    let bitrate = (Double(bytesSinceLast) * 8.0) / elapsed / 1000.0

    window.bytes = currentBytes
    window.timestamp = now

    return bitrate
  }

  func reset() {
    videoFramesSent = 0
    videoKeyFramesSent = 0
    audioFramesSent = 0
    videoBytesSent = 0
    audioBytesSent = 0
    currentVideoTimestamp = 0
    currentAudioTimestamp = 0
    videoBitrateWindow = BitrateWindow()
    audioBitrateWindow = BitrateWindow()
  }
}
