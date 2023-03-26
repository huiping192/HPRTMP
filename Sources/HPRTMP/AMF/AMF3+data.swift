//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/03/26.
//

import Foundation

protocol AMF3Encode {
  var amf3Encode: Data { get }
}

protocol AMF3KeyEncode {
  var amf3KeyEncode: Data { get }
}


extension Bool: AMF3Encode {
  var amf3Encode: Data {
    return Data([self == false ? 0x02 : 0x03])
  }
}


extension Int: AMF3Encode {
  var amf3Encode: Data {
    if self >= -268435456 && self <= 268435455 {
      var data = Data()
      data.append(0x04)
      if self >= 0 {
        data.write(UInt29(self))
      } else {
        let value = UInt29(bitPattern: self)
        data.write(value | 0x10000000)
      }
      return data
    } else {
      var data = Data([0x05])
      data.append(Int32(self).byteSwapped.data)
      return data
    }
  }
}

extension Double: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x05])
    data.append(Data(self.bitPattern.data.reversed()))
    return data
  }
}

extension String: AMF3Encode, AMF3KeyEncode {
  var amf3Encode: Data {
    var data = Data([0x06])
    let utf8Data = Data(utf8)
    data.write(UInt29(utf8Data.count + 1))
    data.append(utf8Data)
    data.append(0x01) // null terminator
    return data
  }
  
  var amf3KeyEncode: Data {
    var data = Data([0x06])
    let utf8Data = Data(utf8)
    data.write(UInt29(utf8Data.count))
    data.append(utf8Data)
    return data
  }
}

extension Date: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x08])
    data.write(UInt29(0))
    data.append(Double(timeIntervalSince1970).amf3Encode)
    return data
  }
}

extension Array: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x09])
    data.write(UInt29(self.count | 0x01))
    data.append(0x01)
    self.forEach { item in
      if let encode = (item as? AMF3Encode)?.amf3Encode {
        data.append(encode)
      } else {
        data.append(Data([0x01]))
      }
    }
    return data
  }
}

extension Dictionary: AMF3Encode where Key: AMF3KeyEncode, Value: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x03]) // Object marker
    var referenceTable: [AnyHashable: Int] = [:] // Used to store object references
    
    // Write object traits
    data.append(Data([0x0b])) // Trait type (object)
    data.append(Data([0x01])) // Trait count (1)
    data.append(self.keys.count.amf3Encode) // Write number of keys
    data.append(Data([0x01])) // Trait property name (always an empty string)
    
    for key in self.keys {
      data.append(key.amf3KeyEncode) // Write the key as a string
      data.append(self[key]!.amf3Encode) // Write the value
    }
    
    return data
  }
}
