import Foundation

protocol NetworkConnectable: Sendable {
  func connect(host: String, port: Int, enableTLS: Bool) async throws
  func sendData(_ data: Data) async throws
  func receiveData() async throws -> Data
  func close() async throws
}
