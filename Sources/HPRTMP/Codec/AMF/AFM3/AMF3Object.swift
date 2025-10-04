//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation

enum AMF3EncodeType {
    enum U29: UInt8 {
        case value = 0x01
        case reference = 0x00

        init?(rawValue: UInt8) {
            switch rawValue {
            case 0x00: self = .reference
            case 0x01: self = .value
            default: return nil
            }
        }
    }

    enum Vector: UInt8 {
        case fix = 0x01
        case dynamic = 0x00
    }
}

enum RTMPAMF3Type: UInt8 {
    case undefined  = 0x00
    case null       = 0x01
    case boolFalse  = 0x02
    case boolTrue   = 0x03
    case int        = 0x04
    case double     = 0x05
    case string     = 0x06
    case xml        = 0x07
    case date       = 0x08
    case array      = 0x09
    case object     = 0x0a
    case xmlEnd     = 0x0b
    case byteArray  = 0x0c
    case vectorInt  = 0x0d
    case vectorUInt  = 0x0e
    case vectorDouble = 0x0f
    case vectorObject = 0x10
    case dictionary   = 0x11
    public init?(rawValue: UInt8) {
        switch rawValue {
        case 0x00: self = .undefined
        case 0x01: self = .null
        case 0x02: self = .boolFalse
        case 0x03: self = .boolTrue
        case 0x04: self = .int
        case 0x05: self = .double
        case 0x06: self = .string
        case 0x07: self = .xml
        case 0x08: self = .date
        case 0x09: self = .array
        case 0x0a: self = .object
        case 0x0b: self = .xmlEnd
        case 0x0c: self = .byteArray
        case 0x0d: self = .vectorInt
        case 0x0e: self = .vectorUInt
        case 0x0f: self = .vectorDouble
        case 0x10: self = .vectorObject
        case 0x11: self = .dictionary
        default:
            return nil
        }
    }

}

struct AMF3Object: AMF3Protocol {
  var data = Data()
  
  mutating func appendUndefined() {
    data.append(RTMPAMF3Type.undefined.rawValue)
  }
  
  mutating func appendNil() {
    data.append(RTMPAMF3Type.null.rawValue)
  }
  
  mutating func appned(_ value: Bool) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: Int) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: Double) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: String) {
    data.append(value.amf3Value)
  }
  
  mutating func appendXML(_ value: String) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: Date) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: [Any]) {
    data.append(value.amf3Value)
  }
  
  mutating func append(_ value: [String: Any?]?) {
    if let v = value {
      data.append(v.amf3Value)
    }
  }
  
  mutating func appendVector(_ value: [Int32]) {
    data.append(value.amf3VectorValue)
  }
  
  mutating func appendVector(_ value: [UInt32]) {
    data.append(value.amf3VectorValue)
  }
  
  mutating func appendVector(_ value: [Double]) {
    data.append(value.amf3VectorValue)
  }
  
  mutating func appendByteArray(_ value: Data) {
    data.append(value.amf3ByteValue)
  }
  
  public func decode() -> [Any]? {
    data.decodeAMF3()
  }
  
  public static func decode(_ data: Data) -> [Any]? {
    data.decodeAMF3()
  }
}


