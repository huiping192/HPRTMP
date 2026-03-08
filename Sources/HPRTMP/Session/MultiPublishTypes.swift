//
//  MultiPublishTypes.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/03/08.
//

import Foundation

// MARK: - MultiPublishStatus

/// Overall status of multi-publish session
public enum OverallStatus: Sendable, Equatable {
  case idle
  case active
  case stopping
  case stopped
}

/// Status of a single destination
public struct DestinationStatus: Sendable, Equatable {
  public let id: String
  public let url: String
  public let sessionStatus: RTMPSessionStatus
  public let isConnected: Bool
  public let error: RTMPError?
  public let retryCount: Int

  public init(
    id: String,
    url: String,
    sessionStatus: RTMPSessionStatus,
    isConnected: Bool,
    error: RTMPError?,
    retryCount: Int
  ) {
    self.id = id
    self.url = url
    self.sessionStatus = sessionStatus
    self.isConnected = isConnected
    self.error = error
    self.retryCount = retryCount
  }
}

/// Aggregated status of all destinations
public struct MultiPublishStatus: Sendable, Equatable {
  public let overallStatus: OverallStatus
  public let destinations: [String: DestinationStatus]

  public init(overallStatus: OverallStatus, destinations: [String: DestinationStatus]) {
    self.overallStatus = overallStatus
    self.destinations = destinations
  }
}

// MARK: - MultiPublishStatistics

/// Statistics for a single destination
public struct DestinationStatistics: Sendable {
  public let id: String
  public let transmissionStatistics: TransmissionStatistics

  public init(id: String, transmissionStatistics: TransmissionStatistics) {
    self.id = id
    self.transmissionStatistics = transmissionStatistics
  }
}

/// Aggregated statistics from all destinations
public struct MultiPublishStatistics: Sendable {
  public let timestamp: Date
  public let destinations: [String: TransmissionStatistics]

  public init(timestamp: Date, destinations: [String: TransmissionStatistics]) {
    self.timestamp = timestamp
    self.destinations = destinations
  }
}

// MARK: - Retry Configuration

/// Configuration for retry behavior
public struct RetryConfiguration: Sendable {
  public let maxRetries: Int
  public let initialDelayMs: UInt64
  public let maxDelayMs: UInt64
  public let backoffMultiplier: Double

  public static let `default` = RetryConfiguration(
    maxRetries: 3,
    initialDelayMs: 1000,
    maxDelayMs: 30000,
    backoffMultiplier: 2.0
  )

  public init(maxRetries: Int, initialDelayMs: UInt64, maxDelayMs: UInt64, backoffMultiplier: Double) {
    self.maxRetries = maxRetries
    self.initialDelayMs = initialDelayMs
    self.maxDelayMs = maxDelayMs
    self.backoffMultiplier = backoffMultiplier
  }

  /// Calculate delay for a given retry attempt
  public func delayForRetry(_ attempt: Int) -> UInt64 {
    let delay = initialDelayMs * UInt64(pow(backoffMultiplier, Double(attempt)))
    return min(delay, maxDelayMs)
  }
}

// MARK: - Failure Strategy

/// Strategy when a destination fails
public enum FailureStrategy: Sendable {
  case continueOthers
  case stopAll
  case retryAndContinue
}

// MARK: - Internal Types

/// Destination configuration
struct DestinationConfig: Sendable {
  let id: String
  let url: String
  let configure: PublishConfigure

  init(id: String, url: String, configure: PublishConfigure) {
    self.id = id
    self.url = url
    self.configure = configure
  }
}
