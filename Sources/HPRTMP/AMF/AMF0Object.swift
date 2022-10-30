//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/29.
//

import Foundation

struct AMF0Object: AMF0Protocol {
    var data = Data()
    
    mutating func append(_ value: Double) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func append(_ value: String) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func appned(_ value: Bool) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func append(_ value: [String: Any?]?) {
        if let v = value {
//            data.extendWrite.write(v.amf0Encode)
        }
    }
    
    mutating func append(_ value: Date) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func appendNil() {
//        data.extendWrite.write(RTMPAMF0Type.null.rawValue)
    }
    
    mutating func append(_ value: [Any]) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func append(_ value: [String: Any?]) {
//        data.extendWrite.write(value.amf0Encode)
    }
    
    mutating func appendXML(_ value: String) {
//        data.extendWrite.write(value)
    }
    
    mutating func appendEcma(_ value: [String: Any?]) {
//        data.extendWrite.write(value.amf0EcmaArray)
    }
    
    mutating func decode() -> [Any]? {
      return nil
//        return self.data.decodeAMF0()
    }
    
    static func decode(_ data: Data) -> [Any]? {
      return nil
//        return data.decodeAMF0()
    }
}
