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
    data.append(Data(self.data.reversed()))
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
}

// Date - 0x0b (Encoded as IEEE 64-bit double-precision floating point number with 16-bit integer time zone offset)
extension Date: AMF0Encode {
  var amf0Value: Data {
    let mileSecondSince1970 = Double(self.timeIntervalSince1970 * 1000)
    var data = Data()
    data.write(RTMPAMF0Type.date.rawValue)
    data.append(Data(mileSecondSince1970.data.reversed()))
    data.write([UInt8]([0x0,0x0]))
    return data
  }
}
