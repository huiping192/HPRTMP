//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/02.
//

import Foundation

enum AMF0DecodeError: Error {
  case rangeError
  case parseError
}


extension Data {
  func subdata(safe range: Range<Int>) -> Data? {
    if range.lowerBound < 0 || range.upperBound > count {
      return nil
    }
    return subdata(in: range)
  }
}

// Decode
extension Data {
  var int: Int {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Int.self)
    }
  }
  
  var uint8: UInt8 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt8.self)
    }
  }
  
  var uint16: UInt16 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt16.self)
    }
  }
  
  var int32: Int32 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Int32.self)
    }
  }
  
  var uint32: UInt32 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt32.self)
    }
  }
  
  var float: Float {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Float.self)
    }
  }
  
  var double: Double {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Double.self)
    }
  }
  
  var string: String {
    return String(data: self, encoding: .utf8) ?? ""
  }
}


extension Data {
  mutating func decode() throws -> [Any]? {
    var decodeData = [Any]()
    while let first = self.first {
      guard let realType = RTMPAMF0Type(rawValue: first) else {
        return decodeData
      }
      
      self.removeFirst()
      do {
        try decodeData.append(self.parseValue(type: realType))
      } catch {
        print("Decode Error \(error.localizedDescription)")
        return nil
      }
    }
    return decodeData
  }
  
  
  mutating func parseValue(type: RTMPAMF0Type) throws -> Any {
    switch type {
    case .number:
      return try decodeNumber()
    case .boolean:
      return try decodeBool()
    case .string:
      return try decodeString()
    case .longString:
      return try decodeLongString()
    case .null:
      return "null"
    case .xml:
      return try decodeXML()
    case .date:
      return try decodeXML()
    case .object:
      return try decodeObj()
    case .typedObject:
      return try decodeTypeObject()
    case .array:
      return try deocdeArray()
    case .strictArray:
      return try decodeStrictArray()
    case .switchAMF3:
      return "Need implement"
    default:
      return AMF0DecodeError.parseError
    }
  }
  
  mutating func decodeNumber() throws -> Double {
    let range = 0..<8
    guard let result = subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    removeSubrange(range)
    return Data(result.reversed()).double
  }
  
  mutating func decodeBool() throws -> Bool {
    guard let result = first else {
      throw AMF0DecodeError.rangeError
    }
    removeFirst()
    return result == 0x01
  }
  mutating func decodeString(type: RTMPAMF0Type) throws -> String {
    let range = 0..<2
    guard let rangeBytes = subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    removeSubrange(range)
    let value = self[0..<Int(length)].string
    removeSubrange(0..<Int(length))
    return value
  }
  
  mutating func decodeString() throws -> String {
    let range = 0..<2
    guard let rangeBytes = subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    removeSubrange(range)
    let value = self[0..<Int(length)].string
    removeSubrange(0..<Int(length))
    return value
  }
  
  mutating func decodeLongString() throws -> String {
    let range = 0..<4
    guard let rangeBytes = subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    removeSubrange(range)
    let value = self[0..<Int(length)].string
    removeSubrange(0..<Int(length))
    return value
  }
  mutating func decodeXML() throws -> String {
    let range = 0..<4
    guard let rangeBytes = subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    removeSubrange(range)
    
    guard let stringBytes = subdata(safe: 0..<Int(length)) else {
      throw AMF0DecodeError.rangeError
    }
    let value = stringBytes.string
    removeSubrange(0..<Int(length))
    return value
  }
  
  mutating func decodeDate() throws -> Date {
    guard let value = subdata(safe: 0..<8) else {
      throw AMF0DecodeError.rangeError
    }
    let convert = Data(value.reversed()).double
    let result = Date(timeIntervalSince1970: convert / 1000)
    removeSubrange(0..<10)
    return result
  }
  
  mutating func decodeObj() throws -> [String: Any] {
    var map = [String: Any]()
    var key = ""
    while let first = self.first, first != RTMPAMF0Type.objectEnd.rawValue {
      var type: RTMPAMF0Type? = RTMPAMF0Type(rawValue: first)
      if key.isEmpty {
        type = .string
        let value = try decodeString(type: .string)
        key = value
        continue
      }
      
      guard let t = type else {
        throw AMF0DecodeError.rangeError
      }
      remove(at: 0)
      
      switch t {
      case .string, .longString:
        let value = try decodeString(type: t)
        map[key] = value
        key = ""
      default:
        
        let value = try self.parseValue(type: t)
        map[key] = value
        key = ""
      }
    }
    remove(at: 0)
    
    return map
  }
  
  mutating func decodeTypeObject() throws -> [String: Any] {
    let range = 0..<4
    removeSubrange(range)
    return try self.decodeObj()
  }
  
  mutating func deocdeArray() throws -> [String: Any] {
    let entryPoint = 0..<4
    self.removeSubrange(entryPoint)
    let value = try self.decodeObj()
    return value
  }
  
  mutating func decodeStrictArray() throws -> [Any] {
    let entryPoint = 0..<4
    guard let rangeBytes = subdata(safe: entryPoint) else {
      throw AMF0DecodeError.rangeError
    }
    var decodeData = [Any]()
    
    var count = Int(Data(rangeBytes.reversed()).uint32)
    removeSubrange(entryPoint)
    while let first = self.first, count != 0 {
      guard let type = RTMPAMF0Type(rawValue: first) else {
        throw AMF0DecodeError.rangeError
      }
      remove(at: 0)
      try decodeData.append(self.parseValue(type: type))
      count -= 1
    }
    return decodeData
  }
  
}
