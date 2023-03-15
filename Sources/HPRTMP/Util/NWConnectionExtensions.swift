//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/03/15.
//

import Foundation
import Network


extension NWConnection {
  private static let maxReadSize = Int(UInt16.max)
  
  func sendData(datas: [Data]) async throws -> Void {
    for data in datas {
      try await sendData(data: data)
    }
  }

  func sendData(data: Data) async throws -> Void {
    try await withCheckedThrowingContinuation {  (continuation: CheckedContinuation<Void, Error>) in
      self.send(content: data, completion: .contentProcessed({error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: ())
      }))
    }
  }
  
  func receiveData() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      self.receive(minimumIncompleteLength: Int(1), maximumLength: NWConnection.maxReadSize) { data, context, isComplete, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        
        guard let data else { return }
        continuation.resume(returning: data)
      }
    }
  }
}
