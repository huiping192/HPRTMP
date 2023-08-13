import Foundation
import Network

extension NWConnection {
  static var maxReadSize = Int(UInt16.max)
  
  func sendData(_ datas: [Data]) async throws -> Void {
    for data in datas {
      try await sendData(data)
    }
  }

  func sendData(_ data: Data) async throws -> Void {
    try await withCheckedThrowingContinuation {  [weak self](continuation: CheckedContinuation<Void, Error>) in
      guard let self else {
        continuation.resume(returning: ())
        return
      }
      self.send(content: data, completion: .contentProcessed({error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }))
    }
  }
  func receiveData() async throws -> Data {
    try await withCheckedThrowingContinuation { [weak self]continuation in
      guard let self else {
        continuation.resume(returning: Data())
        return
      }
      self.receive(minimumIncompleteLength: 0, maximumLength: NWConnection.maxReadSize) { data, context, isComplete, error in
        if let error {
          continuation.resume(throwing: error)
          return
        } else {
          continuation.resume(returning: data ?? Data())
        }
      }
    }
  }
}
