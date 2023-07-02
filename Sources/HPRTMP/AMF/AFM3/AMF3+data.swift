//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/03/26.
//

import Foundation

protocol AMF3Encodable {
  var amf3Value: Data { get }
}

protocol AMF3KeyEncodable {
  var amf3KeyValue: Data { get }
}

protocol AMF3ByteArrayEncodable {
  var amf3ByteValue: Data { get }
}

protocol AMF3VectorEncodable {
  var amf3VectorValue: Data { get }
}

protocol AMF3VectorUnitEncodable {
  var amf3VectorUnitValue: Data { get }
}


extension Bool: AMF3Encodable {
  var amf3Value: Data {
    return Data([self == false ? 0x02 : 0x03])
  }
}


extension Int: AMF3Encodable {
  var amf3Value: Data {
    var data = Data()
    data.write(RTMPAMF3Type.int.rawValue)
    data.append(amf3LengthConvert)
    return data
  }
  var amf3LengthConvert: Data {
    switch self {
    case 0...0x7f:
      return Data([UInt8(self)])
    case 0x80...0x3fff:
      let first  = UInt8(self >> 7 | 0x80)
      let second = UInt8(self & 0x7f)
      return Data([first, second])
    case 0x00004000...0x001fffff:
      let first  = UInt8((self >> 14 & 0x7f) | 0x80)
      let second = UInt8((self >> 7 & 0x7f) | 0x80)
      let third  = UInt8(self & 0x7f)
      return Data([first, second, third])
    case 0x00200000...0x1fffffff:
      let first  = UInt8((self >> 22 & 0x7f) | 0x80)
      let second = UInt8((self >> 15 & 0x7f) | 0x80)
      let third  = UInt8((self >> 8 & 0x7f) | 0x80)
      let four   = UInt8(self & 0xff)
      return Data([first, second, third, four])
    default: // out of range auto convert to double
      return Double(self).amf3Value
    }
  }
  
  var vectorData: Data {
    return self.bigEndian.data
  }
}

extension Double: AMF3Encodable {
  var amf3Value: Data {
    var data = Data([0x05])
    data.append(Data(self.bitPattern.data.reversed()))
    return data
  }
}

extension String: AMF3Encodable, AMF3KeyEncodable {
  var amf3KeyValue: Data {
    let encodeLength = (self.count << 1 | 0x01).amf3LengthConvert
    var data = Data()
    data.append(encodeLength)
    data.append(Data(self.utf8))
    return data
  }
  
  var amf3Value: Data {
    var data = Data()
    data.write(RTMPAMF3Type.string.rawValue)
    data.append(self.amf3KeyValue)
    return data
  }
}

extension Date: AMF3Encodable {
  var amf3Value: Data {
    let mileSecondSince1970 = Double(self.timeIntervalSince1970 * 1000)
    var data = Data()
    data.write(RTMPAMF3Type.date.rawValue)
    data.write(AMF3EncodeType.U29.value.rawValue)
    data.append(Data(mileSecondSince1970.data.reversed()))
    return data
  }
}

extension Dictionary: AMF3Encodable where Key: AMF3KeyEncodable, Value: AMF3Encodable {
  var amf3Value: Data {
    var data = Data([0x03]) // Object marker
    
    // Write object traits
    data.append(Data([0x0b])) // Trait type (object)
    data.append(Data([0x01])) // Trait count (1)
    data.append(self.keys.count.amf3Value) // Write number of keys
    data.append(Data([0x01])) // Trait property name (always an empty string)
    
    for key in self.keys {
      data.append(key.amf3KeyValue) // Write the key as a string
      data.append(self[key]!.amf3Value) // Write the value
    }
    
    return data
  }
}

extension Dictionary where Key == String {
  var amf3Value: Data {
    var data = Data()
    data.write([RTMPAMF3Type.object.rawValue,0x0b,RTMPAMF3Type.null.rawValue])
    self.forEach { (key, value) in
      let keyEncode = key.amf3KeyValue
      data.append(keyEncode)
      if let value = (value as? AMF3Encodable)?.amf3Value {
        data.append(value)
      } else {
        data.write(RTMPAMF3Type.null.rawValue)
      }
    }
    data.write(RTMPAMF3Type.null.rawValue)
    return data
  }
}

extension Array: AMF3Encodable {
  var amf3Value: Data {
    let encodeLength = (self.count << 1 | 0x01).amf3LengthConvert
    var data = Data()
    data.write(RTMPAMF3Type.array.rawValue)
    data.append(encodeLength)
    
    self.forEach {
      if let valueEncode = ($0 as? AMF3Encodable)?.amf3Value {
        data.append(valueEncode)
      }
    }
    return data
  }
}

extension Array: AMF3VectorEncodable {
  var amf3VectorValue: Data {
    var type: RTMPAMF3Type?
    if Element.self == UInt32.self {
      type = .vectorUInt
    } else if Element.self == Int32.self {
      type = .vectorInt
    } else if Element.self == Double.self {
      type = .vectorDouble
    } else {
      type = .vectorObject
    }
    
    guard let t = type else {
      return Data()
    }
    
    let encodeLength = (self.count << 1 | 0x01).amf3LengthConvert
    var data = Data()
    data.write(t.rawValue)
    data.append(encodeLength)
    data.write(AMF3EncodeType.Vector.dynamic.rawValue)
    
    if type == .vectorObject {
      let objectType = "*".amf3Value
      let encodeLength = (objectType.count << 1 | 0x01).amf3LengthConvert
      data.append(encodeLength)
      data.append(objectType)
      self.forEach({
        if let encode = ($0 as? AMF3Encodable)?.amf3Value {
          data.append(encode)
        }
      })
    } else {
      self.forEach {
        if let encode = ($0 as? AMF3VectorUnitEncodable)?.amf3VectorUnitValue {
          data.append(encode)
        }
      }
    }
    
    return data
  }
}

extension Data: AMF3ByteArrayEncodable {
  var amf3ByteValue: Data {
    let encodeLength = (self.count << 1 | 0x01).amf3LengthConvert
    var data = Data()
    data.write(RTMPAMF3Type.byteArray.rawValue)
    data += (encodeLength+self)
    return data
  }
}
