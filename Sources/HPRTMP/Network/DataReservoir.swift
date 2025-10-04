import Foundation
import NIO

/**
 Data Reservoir. If data is available, use that data exactly once.
 If data is not available, wait data is coming with promise.
 When data is coming, client must call dataArrived.
 */
actor DataReservoir {
  private var cachedData: Data = .init()
  private var dataPromise: EventLoopPromise<Data>?

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

  func waitData(with promise: EventLoopPromise<Data>) async throws -> Data {
    self.dataPromise = promise
    return try await promise.futureResult.get()
  }

  func dataArrived(data: Data) {
    cachedData.append(data)
    if let promise = dataPromise {
      self.dataPromise = nil
      guard let current = tryRetrieveCache() else {
        promise.fail(RTMPError.dataRetrievalFailed)
        return
      }
      promise.succeed(current)
    }
  }

  func close() {
    dataPromise?.fail(RTMPError.connectionInvalidated)
    dataPromise = nil
    cachedData = Data()
  }
}
