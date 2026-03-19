import Foundation
@testable import HPRTMP

actor MockNetworkClient: NetworkConnectable {
  private var receivedDataQueue: [Data] = []
  private var currentIndex = 0
  private(set) var sentPackets: [Data] = []

  func setReceivedDataQueue(_ queue: [Data]) {
    self.receivedDataQueue = queue
    self.currentIndex = 0
  }

  func connect(host: String, port: Int, enableTLS: Bool) async throws {
    // Mock implementation
  }

  func sendData(_ data: Data) async throws {
    sentPackets.append(data)
  }

  func receiveData() async throws -> Data {
    guard currentIndex < receivedDataQueue.count else {
      throw RTMPError.dataRetrievalFailed
    }

    let data = receivedDataQueue[currentIndex]
    currentIndex += 1
    return data
  }

  func close() async throws {
    // Mock implementation
  }
}
