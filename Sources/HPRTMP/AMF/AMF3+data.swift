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

protocol AMF3ByteArrayEncode {
  var byteEncode: Data { get }
}

protocol AMF3VectorEncode {
  var amf3VectorEncode: Data { get }
}

protocol AMF3VectorUnitEncode {
  var vectorData: Data { get }
}


extension Bool: AMF3Encode {
  var amf3Encode: Data {
    return Data([self == false ? 0x02 : 0x03])
  }
}


extension Int: AMF3Encode {
  var amf3Encode: Data {
//    if self >= -268435456 && self <= 268435455 {
//      var data = Data()
//      data.append(0x04)
//      if self >= 0 {
//        data.write(UInt29(self))
//      } else {
//        let value = UInt29(bitPattern: self)
//        data.write(value | 0x10000000)
//      }
//      return data
//    } else {
//      var data = Data([0x05])
//      data.append(Int32(self).byteSwapped.data)
//      return data
//    }
    return Data()
  }
  
  var vectorData: Data {
      return self.bigEndian.data
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
//    let utf8Data = Data(utf8)
//    data.write(UInt29(utf8Data.count + 1))
//    data.append(utf8Data)
//    data.append(0x01) // null terminator
    return data
  }
  
  var amf3KeyEncode: Data {
    var data = Data([0x06])
//    let utf8Data = Data(utf8)
//    data.write(UInt29(utf8Data.count))
//    data.append(utf8Data)
    return data
  }
}

extension Date: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x08])
//    data.write(UInt29(0))
//    data.append(Double(timeIntervalSince1970).amf3Encode)
    return data
  }
}

extension Array: AMF3Encode {
  var amf3Encode: Data {
    var data = Data([0x09])
//    data.write(UInt29(self.count | 0x01))
//    data.append(0x01)
//    self.forEach { item in
//      if let encode = (item as? AMF3Encode)?.amf3Encode {
//        data.append(encode)
//      } else {
//        data.append(Data([0x01]))
//      }
//    }
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

extension Dictionary where Key == String {
    var amf3Encode: Data {
        var data = Data()
//        data.extendWrite.write([RTMPAMF3Type.object.rawValue,0x0b,RTMPAMF3Type.null.rawValue])
//        self.forEach { (key, value) in
//            let keyEncode = key.amf3KeyEncode
//            data.append(keyEncode)
//            if let value = (value as? AMF3Encode)?.amf3Encode {
//                data.append(value)
//            } else {
//                data.extendWrite.write(RTMPAMF3Type.null.rawValue)
//            }
//        }
//        data.extendWrite.write(RTMPAMF3Type.null.rawValue)
        return data
    }
}

extension Array: AMF3VectorEncode {
    var amf3VectorEncode: Data {
//        var type: RTMPAMF3Type?
//        if Element.self == UInt32.self {
//            type = .vectorUInt
//        } else if Element.self == Int32.self {
//            type = .vectorInt
//        } else if Element.self == Double.self {
//            type = .vectorDouble
//        } else {
//            type = .vectorObject
//        }
//
//        guard let t = type else {
//            return Data()
//        }
//
//        let encodeLength = (self.count << 1 | 0x01).amf3LengthConvert
//        var data = Data()
//        data.extendWrite.write(t.rawValue)
//            .write(encodeLength)
//            .write(AMF3EncodeType.Vector.dynamic.rawValue)
//
//        if type == .vectorObject {
//            var objectType = "*".amf3Encode
//            let encodeLength = (objectType.count << 1 | 0x01).amf3LengthConvert
//            data.extendWrite.write(encodeLength)
//                            .write(objectType)
//            self.forEach({
//                if let encode = ($0 as? AMF3Encode)?.amf3Encode {
//                    data.extendWrite.write(encode)
//                }
//            })
//        } else {
//            self.forEach {
//                if let encode = ($0 as? AMF3VectorUnitEncode)?.vectorData {
//                    data.extendWrite.write(encode)
//                }
//            }
//        }
//
//        return data
      return Data()
    }
}
