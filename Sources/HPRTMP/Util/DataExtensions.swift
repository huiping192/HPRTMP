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
  
  mutating func write(_ value: UInt16) {
    self.append(value.bigEndian.data)
  }
  
  mutating func write(_ value: UInt32) {
    self.append(value.bigEndian.data)
  }
  
  mutating func writeU24(_ value: Int, bigEndian: Bool) {
    if bigEndian {
      let convert = UInt32(value).bigEndian.data
      append(convert[1...(convert.count-1)])
    } else {
      let convert = UInt32(value).data
      append(convert[0..<convert.count-1])
    }
  }
}

extension Data {
  subscript (r: Range<Int>) -> Data {
    let range = Range(uncheckedBounds: (lower: Swift.max(0, r.lowerBound),
                                        upper: Swift.min(count, r.upperBound)))
    return self.subdata(in: range)
  }
  
  subscript (safe range: CountableRange<Int>) -> Data? {
    if range.lowerBound < 0 || range.upperBound > self.count {
      return nil
    }
    
    return self[range]
  }
  
  subscript (safe range: CountableClosedRange<Int>) -> Data? {
    if range.lowerBound < 0 || range.upperBound >= self.count {
      return nil
    }
    
    return self[range]
  }
  
  subscript (safe index: Int) -> UInt8? {
    if index > 0 && index < self.count {
      return self[index]
    }
    return nil
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
