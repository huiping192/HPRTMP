

import Foundation
import Network

protocol RTMPConnectable {
  func connect(host: String, port: UInt16) async throws
  func sendData(_ data: Data) async throws
  func receiveData() async throws -> Data
}

actor NWConnecter: RTMPConnectable {
  private var connection: NWConnection?
  
  public func connect(host: String, port: UInt16) async throws {
    let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 1935, using: .tcp)
    self.connection = connection
    connection.stateUpdateHandler = { [weak self] newState in
      guard let self else { return }
      Task {
        switch newState {
        case .ready:
          break
        case .failed(let error):
          break
        default:
          break
        }
      }
    }
//    NWConnection.maxReadSize = Int((await windowControl.windowSize))
    connection.start(queue: DispatchQueue.global(qos: .default))
  }
  
  func sendData(_ data: Data) async throws {
    try await connection?.sendData(data)
  }
  
  func receiveData() async throws -> Data {
    guard let connection = self.connection else { return Data() }
    return try await connection.receiveData()
  }
}
