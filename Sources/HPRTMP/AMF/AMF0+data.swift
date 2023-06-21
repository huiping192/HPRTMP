//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/31.
//

import Foundation

enum RTMPAMF0Type: UInt8 {
  case number      = 0x00
  case boolean     = 0x01
  case string      = 0x02
  case object      = 0x03
  case null        = 0x05
  case array       = 0x08
  case objectEnd   = 0x09
  case strictArray = 0x0a
  case date        = 0x0b
  case longString  = 0x0c
  case xml         = 0x0f
  case typedObject = 0x10
  case switchAMF3  = 0x11
}

extension Int: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension Int8: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension Int16: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension Int32: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension UInt: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension UInt8: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension UInt16: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension UInt32: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

extension Float: AMF0Encode {
  var amf0Value: Data {
    return Double(self).amf0Value
  }
}

// Number - 0x00 (Encoded as IEEE 64-bit double-precision floating point number)
extension Double: AMF0Encode {
  var amf0Value: Data {
    var data = Data()
    data.write(RTMPAMF0Type.number.rawValue)
    // bigEndian
    data.append(Data(self.bitPattern.bigEndian.data))
    return data
  }
}

// Boolean - 0x01 (Encoded as a single byte of value 0x00 or 0x01)
extension Bool: AMF0Encode {
  var amf0Value: Data {
    var data = Data()
    data.write(RTMPAMF0Type.boolean.rawValue)
    let value: UInt8 = self ? 0x01 : 0x00
    data.write(value)
    return data
  }
}

// String - 0x02 (16-bit integer string length with UTF-8 string)
// Long String - 0x0c (32-bit integer string length with UTF-8 string)
extension String: AMF0Encode {
  var amf0Value: Data {
    let isLongString = self.count > UInt16.max
    return isLongString ? amf0LongStringValue : amf0StringValue
  }

  private var amf0StringValue: Data {
    var data = Data()

    data.write(RTMPAMF0Type.string.rawValue)
    data.append(UInt16(Data(self.utf8).count).bigEndian.data)
    data.append(Data(self.utf8))

    return data
  }

  private var amf0LongStringValue: Data {
    var data = Data()

    data.write(RTMPAMF0Type.longString.rawValue)
    data.append(UInt32(Data(self.utf8).count).bigEndian.data)
    data.append(Data(self.utf8))

    return data
  }

  var amf0KeyEncode: Data {
    let isLong = UInt32(UInt16.max) < UInt32(self.count)

    var data = Data()
    let convert = Data(self.utf8)
    if isLong {
      data.append(UInt32(convert.count).bigEndian.data)
    } else {
      data.append(UInt16(convert.count).bigEndian.data)
    }
    data.append(Data(self.utf8))
    return data
  }
}

// Date - 0x0b (Encoded as IEEE 64-bit double-precision floating point number with 16-bit integer time zone offset)
extension Date: AMF0Encode {
  var amf0Value: Data {
    let mileSecondSince1970 = Double(UInt64(self.timeIntervalSince1970 * 1000))
    var data = Data()
    data.write(RTMPAMF0Type.date.rawValue)
    data.append(Data(mileSecondSince1970.bitPattern.data))
    data.write([UInt8]([0x0, 0x0]))
    return data
  }
}

// Object - 0x03 (Set of key/value pairs)
// Object End - 0x09 (preceded by an empty 16-bit string length)
extension Dictionary where Key == String {
  var amf0Encode: Data {
    var data = Data()
    data.write(RTMPAMF0Type.object.rawValue)
    data.append(keyValueEncode())
    data.write([0x00, 0x00, RTMPAMF0Type.objectEnd.rawValue])
    return data
  }

  // ECMA Array
  var amf0EcmaArray: Data {
    var data = Data()
    data.write(RTMPAMF0Type.array.rawValue)
    data.write(UInt32(self.count))
    data.append(self.keyValueEncode())
    return data
  }

  fileprivate func keyValueEncode() -> Data {
    var data = Data()
    self.forEach { (key, value) in
      let keyEncode = key.amf0KeyEncode
      data.append(keyEncode)
      if let valueEncode = (value as? AMF0Encode)?.amf0Value {
        data.append(valueEncode)
      } else {
        data.write(RTMPAMF0Type.null.rawValue)
      }
    }
    return data
  }
}

// Strict Array - 0x0a (32-bit entry count)
extension Array: AMF0Encode {
  var amf0Value: Data {
    var data = Data()
    data.write(RTMPAMF0Type.strictArray.rawValue)
    data.write(UInt32(self.count))
    self.forEach {
      if let valueEncode = ($0 as? AMF0Encode)?.amf0Value {
        data.append(valueEncode)
      } else if let dic = $0 as? [String: Any] {
        data.append(dic.amf0Encode)
      }
    }
    return data
  }
}

extension Array {
  var amf0GroupEncode: Data {
    var group = Data()
    self.forEach {
      if let data = ($0 as? AMF0Encode)?.amf0Value {
        group.append(data)
      } else if let dic = $0 as? [String: Any?] {
        group.append(dic.amf0Encode)
      }
    }
    return group
  }
}
