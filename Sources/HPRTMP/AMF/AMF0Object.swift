//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation


protocol AMF0Encode {
  var amf0Value: Data { get }
}

struct AMF0Object: AMF0Protocol {
  var data = Data()
  
  mutating  func appendEcma(_ value: [String : Any?]) {
    data.append(value.amf0EcmaArray)
  }
  
  mutating func append(_ value: Double) {
    data.append(value.amf0Value)
  }
  
  mutating func append(_ value: String) {
    data.append(value.amf0Value)
  }
  
  mutating func appned(_ value: Bool) {
    data.append(value.amf0Value)
  }
  
  mutating func append(_ value: [String : Any?]?) {
    guard let value else { return }
    data.append(value.amf0Encode)
  }
  
  mutating func append(_ value: Date) {
    data.append(value.amf0Value)
  }
  
  mutating func appendNil() {
    data.write(RTMPAMF0Type.null.rawValue)
  }
  
  mutating func append(_ value: [Any]) {
    data.append(value.amf0Value)
  }
  
  mutating func appendXML(_ value: String) {
    // todo
  }
  
  mutating func decode() -> [Any]? {
    data.decodeAMF0()
  }
  
  static func decode(_ data: Data) -> [Any]? {
    var newData = data
    return newData.decodeAMF0()
  }
}
