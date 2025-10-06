//
//  TransmissionStatistics.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

public struct TransmissionStatistics: Sendable {
  let pendingMessageCount: Int

  let totalBytesReceived: UInt32
  let totalBytesSent: UInt32
  let unacknowledgedBytes: Int64
  let windowSize: UInt32
  let windowUtilization: Double

  let videoFramesSent: UInt64
  let videoKeyFramesSent: UInt64
  let audioFramesSent: UInt64

  let videoBytesSent: UInt64
  let audioBytesSent: UInt64

  let videoBitrate: Double
  let audioBitrate: Double

  let currentVideoTimestamp: UInt32
  let currentAudioTimestamp: UInt32

  let pendingVideoFrames: Int
  let pendingAudioFrames: Int
  let pendingOtherMessages: Int
}
