//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/11/02.
//

import Foundation
import os

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
  func decodeAMF0() -> [Any]? {
    let decoder = AMF0Decoder()
    return decoder.decodeAMF0(self)
  }
}

class AMF0Decoder {
  private var data: Data = Data()
  private let logger = Logger(subsystem: "HPRTMP", category: "AMF0Decoder")
  func decodeAMF0(_ data: Data) -> [Any]? {
    self.data = data
    var decodeData = [Any]()
    while let first = self.data.first {
      guard let realType = RTMPAMF0Type(rawValue: first) else {
        return decodeData
      }

      self.data.removeSubrange(0..<1)
      do {
        try decodeData.append(self.parseValue(type: realType))
      } catch {
        logger.error("Decode Error \(error.localizedDescription)")
        return nil
      }
    }
    return decodeData
  }

  func parseValue(type: RTMPAMF0Type) throws -> Any {
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
      return try decodeDate()
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

  func decodeNumber() throws -> Double {
    let range = 0..<8
    guard let result = data.subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    data.removeSubrange(range)
    return Data(result.reversed()).double
  }

  func decodeBool() throws -> Bool {
    guard let result = data.first else {
      throw AMF0DecodeError.rangeError
    }
    data.removeSubrange(0..<1)
    return result == 0x01
  }
  func decodeString() throws -> String {
    let range = 0..<2
    guard let rangeBytes = data.subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint16
    data.removeSubrange(range)
    let value = data[0..<Int(length)].string
    data.removeSubrange(0..<Int(length))
    return value
  }

  func decodeLongString() throws -> String {
    let range = 0..<4
    guard let rangeBytes = data.subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    data.removeSubrange(range)
    let value = data[0..<Int(length)].string
    data.removeSubrange(0..<Int(length))
    return value
  }

  func decodeXML() throws -> String {
    let range = 0..<4
    guard let rangeBytes = data.subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    let length = Data(rangeBytes.reversed()).uint32
    data.removeSubrange(range)

    guard let stringBytes = data.subdata(safe: 0..<Int(length)) else {
      throw AMF0DecodeError.rangeError
    }
    let value = stringBytes.string
    data.removeSubrange(0..<Int(length))
    return value
  }

  func decodeDate() throws -> Date {
    guard let value = data.subdata(safe: 0..<8) else {
      throw AMF0DecodeError.rangeError
    }
    let convert = Data(value).double
    let result = Date(timeIntervalSince1970: convert / 1000)
    data.removeSubrange(0..<10)
    return result
  }

  func decodeObj() throws -> [String: Any] {
    var map = [String: Any]()
    var key = ""
    while let first = data.first, first != RTMPAMF0Type.objectEnd.rawValue {
      var type: RTMPAMF0Type? = RTMPAMF0Type(rawValue: first)
      if key.isEmpty {
        type = .string
        let value = try decodeString()
        key = value
        continue
      }

      guard let type = type else {
        throw AMF0DecodeError.rangeError
      }
      data.removeSubrange(0..<1)

      switch type {
      case .string:
        let value = try decodeString()
        map[key] = value
        key = ""
      case .longString:
        let value = try decodeLongString()
        map[key] = value
        key = ""
      default:

        let value = try self.parseValue(type: type)
        map[key] = value
        key = ""
      }
    }
    data.removeSubrange(0..<1)

    return map
  }

  func decodeTypeObject() throws -> [String: Any] {
    let range = 0..<4
    data.removeSubrange(range)
    return try self.decodeObj()
  }

  func deocdeArray() throws -> [String: Any] {
    let entryPoint = 0..<4
    data.removeSubrange(entryPoint)
    let value = try self.decodeObj()
    return value
  }

  func decodeStrictArray() throws -> [Any] {
    let entryPoint = 0..<4
    guard let rangeBytes = data.subdata(safe: entryPoint) else {
      throw AMF0DecodeError.rangeError
    }
    var decodeData = [Any]()

    var count = Int(Data(rangeBytes.reversed()).uint32)
    data.removeSubrange(entryPoint)
    while let first = data.first, count != 0 {
      guard let type = RTMPAMF0Type(rawValue: first) else {
        throw AMF0DecodeError.rangeError
      }
      data.removeSubrange(0..<1)
      try decodeData.append(self.parseValue(type: type))
      count -= 1
    }
    return decodeData
  }
}
