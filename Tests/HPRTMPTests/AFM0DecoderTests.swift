//
//  AFM0DecodeTests.swift
//  
//
//  Created by 郭 輝平 on 2023/03/28.
//

import XCTest
@testable import HPRTMP

class AMF0DecoderTests: XCTestCase {
  
  func testDecodeNumber() {
    let data = 123.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? Double, 123)
  }
  func testEncodeDecodeNumber() {
    let number = 123.45
    let data = number.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? Double, number)
  }
  
  func testEncodeDecodeString() {
    let string = "Hello, world!"
    let data = string.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? String, string)
  }
  
  func testEncodeDecodeLongString() {
    let longString = "This is a long string that exceeds the maximum size of a regular string in AMF0, which is 65535 bytes."
    let data = longString.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? String, longString)
  }
  
  func testEncodeDecodeBoolean() {
    let boolean = true
    let data = boolean.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? Bool, boolean)
  }
  
  func testEncodeDecodeNull() {
    let data = Data([0x05])
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? String, "null")
  }
  
  
  func testEncodeDecodeObject() {
    let object: [String : Any] = ["foo": "bar", "baz": 123]
    let data = object.afm0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    
    let dic = result?.first as? [String: Any]
    XCTAssertEqual(dic?["foo"] as! String, "bar")
    XCTAssertEqual(dic?["baz"] as! Double, 123)
  }
  
  func testEncodeDecodeArray() {
    let array = ["foo", "bar", 123] as [Any]
    let data = array.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    let resultArray = result?.first as? [Any]
    XCTAssertEqual(resultArray?.first as? String, "foo")
    XCTAssertEqual(resultArray?[1] as? String, "bar")
    XCTAssertEqual(resultArray?[2] as? Double, 123)
  }
  
  func testEncodeDecodeDate() {
    let date = Date(timeIntervalSince1970: 1234567890)
    let data = date.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? Date, date)
  }
  
  func testEncodeDecodeXML() {
    let xml = "<foo>bar</foo>"
    let data = xml.amf0Value
    let decoder = AMF0Decoder()
    let result = decoder.decode(data)
    XCTAssertEqual(result?.first as? String, xml)
  }
  
}
