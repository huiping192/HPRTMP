//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/09/20.
//

import Foundation

extension Data {
  mutating func write(_ value: UInt8) {
    write([value])
  }
  
  mutating func write(_ value: [UInt8]) {
    self.append(contentsOf: value)
  }
  
  mutating func write(_ value: UInt32) {
    self.append(value.bigEndian.data)
  }
}



extension UInt32 {
  func toUInt8Array() -> [UInt8] {
    var bigEndian = self.bigEndian
    let count = MemoryLayout<UInt32>.size
    let bytePtr = withUnsafePointer(to: &bigEndian) {
      $0.withMemoryRebound(to: UInt8.self, capacity: count) {
        UnsafeBufferPointer(start: $0, count: count)
      }
    }
    return Array(bytePtr)
  }
  
}
