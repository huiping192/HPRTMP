//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/07/02.
//

import Foundation

class AMF3Encoder {
  
  func encode(_ value: Any) throws -> Data {
    if let encodableValue = value as? AMF3Encodable {
      return encodableValue.amf3Value
    } else if let encodableValue = value as? AMF3KeyEncodable {
      return encodableValue.amf3KeyValue
    } else if let encodableValue = value as? AMF3ByteArrayEncodable {
      return encodableValue.amf3ByteValue
    } else if let encodableValue = value as? AMF3VectorEncodable {
      return encodableValue.amf3VectorValue
    } else if let encodableValue = value as? AMF3VectorUnitEncodable {
      return encodableValue.amf3VectorUnitValue
    } else {
      throw AMF3EncoderError.unsupportedType
    }
  }
  
  enum AMF3EncoderError: Error {
    case unsupportedType
  }
}
