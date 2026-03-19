//
//  RTMPError.swift
//
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation

public enum RTMPError: Error, Sendable, Equatable {
  case handShake(desc: String)
  case stream(desc: String)
  case command(desc: String)
  case unknown(desc: String)
  case connectionNotEstablished
  case connectionInvalidated
  case dataRetrievalFailed
  case bufferOverflow
  case invalidChunkSize(size: UInt32, min: UInt32, max: UInt32)
}

// MARK: - LocalizedError Conformance
extension RTMPError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .handShake(let desc):
      return desc
    case .stream(let desc):
      return desc
    case .command(let desc):
      return desc
    case .unknown(let desc):
      return desc
    case .connectionNotEstablished:
      return "Connection not established"
    case .connectionInvalidated:
      return "Connection invalidated"
    case .dataRetrievalFailed:
      return "Data retrieval failed unexpectedly"
    case .bufferOverflow:
      return "Buffer overflow: received data exceeds maximum allowed size"
    case .invalidChunkSize(let size, let min, let max):
      return "Invalid chunk size: \(size). Must be between \(min) and \(max)"
    }
  }
}
