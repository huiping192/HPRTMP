//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/06/28.
//

import Foundation

struct AMF0CodingKeys: CodingKey {
   var intValue: Int?
   var stringValue: String

   init?(intValue: Int) {
     self.intValue = intValue
     self.stringValue = "\(intValue)"
   }

   init?(stringValue: String) {
     self.stringValue = stringValue
   }
 }

final class Storage {
  private(set) var containers: [Data] = []
  
  var count: Int {
    return containers.count
  }
  
  var last: Any? {
    return containers.last
  }
  
  func push(container: Data) {
    containers.append(container)
  }
  
  @discardableResult
  func popContainer() -> Data {
    precondition(containers.count > 0, "Empty container stack.")
    return containers.popLast()!
  }
}

class AMF0Encoder: Encoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey : Any] = [:]
  
  private(set) var storage = Storage()

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    return KeyedEncodingContainer(AMF0KeyedEncodingContainer<Key>(storage: storage, codingPath: codingPath))
  }
  
  func unkeyedContainer() -> UnkeyedEncodingContainer {
    return AMF0UnkeyedEncodingContainer()
  }
  
  func singleValueContainer() -> SingleValueEncodingContainer {
    return AMF0SingleValueEncodingContainer()
  }
  
  func encode(_ value: [Any]) throws -> Data? {
    return value.amf0Value
  }
  
  func encode<T: Encodable>(_ value: T) throws -> Data? {
    if let amf0Encode = value as? AMF0Encode {
      return amf0Encode.amf0Value
    }
    
    try value.encode(to: self)
    return storage.popContainer()
  }
  
  func encode(_ value: [String: Any]) throws -> Data? {
    return value.amf0Encode
  }
}

class AMF0KeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  var codingPath: [CodingKey] = []
  var data = Data()
  let storage: Storage
  init(storage: Storage, codingPath: [CodingKey]) {
    self.codingPath = codingPath
    self.storage = storage
    
    data.write(RTMPAMF0Type.object.rawValue)
  }
  
  deinit {
    data.append(contentsOf: [0x00,0x00,RTMPAMF0Type.objectEnd.rawValue])
    storage.push(container: data)
  }
  
  func encodeNil(forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.write(RTMPAMF0Type.null.rawValue)
  }
  
  func encode(_ value: Bool, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: String, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Double, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Int, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Int8, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Int16, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Int32, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Int64, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(Double(value).amf0Value) // Encode Int64 as Double
  }
  
  func encode(_ value: UInt, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: UInt8, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: UInt16, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: UInt32, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: UInt64, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(Double(value).amf0Value) // Encode UInt64 as Double
  }
  
  func encode(_ value: Float, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode(_ value: Date, forKey key: Key) throws {
    data.append(key.stringValue.amf0KeyEncode)
    data.append(value.amf0Value)
  }
  
  func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
    if let value = value as? AMF0Encode {
      data.append(key.stringValue.amf0KeyEncode)
      data.append(value.amf0Value)
    } else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "Unsupported type!"))
    }
  }
  
  func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    fatalError("nestedContainer is not supported.")
  }
  
  func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    fatalError("nestedUnkeyedContainer is not supported.")
  }
  
  func superEncoder() -> Encoder {
    fatalError("superEncoder is not supported.")
  }
  
  func superEncoder(forKey key: Key) -> Encoder {
    fatalError("superEncoder(forKey:) is not supported.")
  }
}


struct AMF0UnkeyedEncodingContainer: UnkeyedEncodingContainer {
  var count: Int = 0
  var codingPath: [CodingKey] = []
  var data = Data()
  
  init() {
    data.write(RTMPAMF0Type.strictArray.rawValue) // write the AMF0 array type
  }
  
  mutating func encodeNil() throws {
    count += 1
    data.write(RTMPAMF0Type.null.rawValue) // write the AMF0 null type
  }
  
  mutating func encode(_ value: Bool) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: String) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Double) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int8) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int16) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int32) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int64) throws {
    count += 1
    data.append(Double(value).amf0Value) // Encode Int64 as Double
  }
  
  mutating func encode(_ value: UInt) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt8) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt16) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt32) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt64) throws {
    count += 1
    data.append(Double(value).amf0Value) // Encode UInt64 as Double
  }
  
  mutating func encode(_ value: Float) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Date) throws {
    count += 1
    data.append(value.amf0Value)
  }
  
  mutating func encode<T>(_ value: T) throws where T : Encodable {
    count += 1
    if let value = value as? AMF0Encode {
      data.append(value.amf0Value)
    } else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "Unsupported type!"))
    }
  }
  
  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    fatalError("Nested keyed container is not supported.")
  }
  
  mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Nested unkeyed container is not supported.")
  }
  
  mutating func superEncoder() -> Encoder {
    fatalError("Super encoder is not supported.")
  }
}

struct AMF0SingleValueEncodingContainer: SingleValueEncodingContainer {
  var codingPath: [CodingKey] = []
  var data = Data()
  
  mutating func encodeNil() throws {
    data.write(RTMPAMF0Type.null.rawValue)
  }
  
  mutating func encode(_ value: Bool) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: String) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Double) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int8) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int16) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int32) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Int64) throws {
    data.append(Double(value).amf0Value) // Encode Int64 as Double
  }
  
  mutating func encode(_ value: UInt) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt8) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt16) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt32) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: UInt64) throws {
    data.append(Double(value).amf0Value) // Encode UInt64 as Double
  }
  
  mutating func encode(_ value: Float) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode(_ value: Date) throws {
    data.append(value.amf0Value)
  }
  
  mutating func encode<T>(_ value: T) throws where T : Encodable {
    if let value = value as? AMF0Encode {
      data.append(value.amf0Value)
    } else {
      throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "Unsupported type!"))
    }
  }
}
