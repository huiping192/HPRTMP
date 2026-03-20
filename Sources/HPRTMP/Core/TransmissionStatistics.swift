//
//  TransmissionStatistics.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

public struct TransmissionStatistics: Sendable {
  public let pendingMessageCount: Int

  public let totalBytesReceived: UInt64
  public let totalBytesSent: UInt64
  public let unacknowledgedBytes: Int64
  public let windowSize: UInt32
  public let windowUtilization: Double

  public let videoFramesSent: UInt64
  public let videoKeyFramesSent: UInt64
  public let audioFramesSent: UInt64

  public let videoBytesSent: UInt64
  public let audioBytesSent: UInt64

  public let videoBitrate: Double
  public let audioBitrate: Double

  public let currentVideoTimestamp: UInt32
  public let currentAudioTimestamp: UInt32

  public let pendingVideoFrames: Int
  public let pendingAudioFrames: Int
  public let pendingOtherMessages: Int
}
