
import Foundation
import os

enum AMF0DecodeError: Error {
  case rangeError
  case parseError
}

extension Data {
  func decodeAMF0() -> [Any]? {
    let decoder = AMF0Decoder()
    return decoder.decode(self)
  }
}

class AMF0Decoder {
  private var data: Data = Data()
  private let logger = Logger(subsystem: "HPRTMP", category: "AMF0Decoder")
  
  func decode(_ data: Data) -> [Any]? {
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
  
  
  private func parseValue(type: RTMPAMF0Type) throws -> Any {
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
  
  private func decodeNumber() throws -> Double {
    let range = 0..<8
    guard let result = data.subdata(safe: range) else {
      throw AMF0DecodeError.rangeError
    }
    data.removeSubrange(range)
    return Data(result.reversed()).double
  }
  
  private func decodeBool() throws -> Bool {
    guard let result = data.first else {
      throw AMF0DecodeError.rangeError
    }
    data.removeSubrange(0..<1)
    return result == 0x01
  }
  private func decodeString() throws -> String {
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
  
  private func decodeLongString() throws -> String {
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
  
  private func decodeXML() throws -> String {
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
  
  private func decodeDate() throws -> Date {
    guard let value = data.subdata(safe: 0..<8) else {
      throw AMF0DecodeError.rangeError
    }
    let convert = Data(value).double
    let result = Date(timeIntervalSince1970: convert / 1000)
    data.removeSubrange(0..<10)
    return result
  }
  
  private func decodeObj() throws -> [String: Any] {
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
      
      guard let t = type else {
        throw AMF0DecodeError.rangeError
      }
      data.removeSubrange(0..<1)
      
      switch t {
      case .string:
        let value = try decodeString()
        map[key] = value
        key = ""
      case .longString:
        let value = try decodeLongString()
        map[key] = value
        key = ""
      default:
        
        let value = try self.parseValue(type: t)
        map[key] = value
        key = ""
      }
    }
    data.removeSubrange(0..<1)
    
    return map
  }
  
  private func decodeTypeObject() throws -> [String: Any] {
    let range = 0..<4
    data.removeSubrange(range)
    return try self.decodeObj()
  }
  
  private func deocdeArray() throws -> [String: Any] {
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

private extension Data {
  func subdata(safe range: Range<Int>) -> Data? {
    if range.lowerBound < 0 || range.upperBound > count {
      return nil
    }
    return subdata(in: range)
  }
}
