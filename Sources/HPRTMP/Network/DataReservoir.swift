import Foundation
import NIO

/**
 Data Reservoir. If data is available, use that data exactly once.
 If data is not available, wait data is coming with promise.
 When data is coming, client must call dataArrived.

 Uses CheckedContinuation instead of NIO's EventLoopPromise for Swift 6 Sendable compliance.
 */
actor DataReservoir {
  private var cachedData: Data = .init()
  private var pendingContinuation: CheckedContinuation<Data, Error>?

  /**
   return cached data if it's not empty.
   Or return nil if it's empty.
   after calling this method, cachedData is renewed.
   */
  func tryRetrieveCache() -> Data? {
    if cachedData.isEmpty {
      return nil
    } else {
      let data = cachedData
      cachedData = Data()
      return data
    }
  }

  func waitData() async throws -> Data {
    if let cached = tryRetrieveCache() {
      return cached
    }
    return try await withCheckedThrowingContinuation { continuation in
      self.pendingContinuation = continuation
    }
  }

  func dataArrived(data: Data) {
    cachedData.append(data)
    if let continuation = pendingContinuation {
      pendingContinuation = nil
      guard let current = tryRetrieveCache() else {
        continuation.resume(throwing: RTMPError.dataRetrievalFailed)
        return
      }
      continuation.resume(returning: current)
    }
  }

  func close() {
    pendingContinuation?.resume(throwing: RTMPError.connectionInvalidated)
    pendingContinuation = nil
    cachedData = Data()
  }
}
