//
//  AMF0EncoderTests.swift
//  
//
//  Created by 郭 輝平 on 2023/06/30.
//

import XCTest
@testable import HPRTMP

final class AMF0EncoderTests: XCTestCase {

    var encoder: AMF0Encoder!

    override func setUpWithError() throws {
        encoder = AMF0Encoder()
    }

    override func tearDownWithError() throws {
        encoder = nil
    }
  
  
  func testAmf0Value() {
    // Number
    XCTAssertEqual(123.amf0Value, Data([0x00, 0x40, 0x5E, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00]))
    XCTAssertEqual(3.14.amf0Value, Data([0x00, 0x40, 0x09, 0x1E, 0xB8, 0x51, 0xEB, 0x85, 0x1F]))

    // Boolean
    XCTAssertEqual(true.amf0Value, Data([0x01, 0x01]))
    XCTAssertEqual(false.amf0Value, Data([0x01, 0x00]))
    
    // String
    XCTAssertEqual("hello".amf0Value, Data([0x02, 0x00, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]))
    
    // Long String
    let longString = String(repeating: "a", count: Int(UInt16.max) + 1)
    XCTAssertEqual(longString.amf0Value, Data([0x0c, 0x00, 0x01, 0x00, 0x00] + Array(repeating: 0x61, count: Int(UInt16.max) + 1)))
    
    // Date
    let date = Date(timeIntervalSince1970: 10.12)
    XCTAssertEqual(date.amf0Value, Data([0x0b, 0x0, 0x0, 0x0, 0x0, 0x0, 0xc4, 0xc3, 0x40, 0x0, 0x0]))

    // Objects
    let object = ["name": "John", "age": 30] as [String: Any]
    let expectedObjectData1 = Data([0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x03, 0x61, 0x67, 0x65, 0x00, 0x40, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09])
    let expectedObjectData2 = Data([0x03, 0x00, 0x03, 0x61, 0x67, 0x65, 0x00, 0x40, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x00, 0x09])
    
    XCTAssert(object.afm0Value == expectedObjectData1 || object.afm0Value == expectedObjectData2)

    // Simple array with Int, String, and Double values
    let array: [Any] = [1, "two", 3.0]
    XCTAssertEqual(array.amf0Value, Data([0x0A, 0x00, 0x00, 0x00, 0x03, 0x00, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x74, 0x77, 0x6F, 0x00, 0x40, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    
    // Array of dictionaries
    let dict1: [String: Any] = ["name": "John"]
    let dict2: [String: Any] = ["name": "Jane"]
    let array2 = [dict1, dict2]

    let expectedData = Data([0x0A, 0x00, 0x00, 0x00, 0x02, 0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x00, 0x09, 0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x61, 0x6E, 0x65, 0x00, 0x00, 0x09])
    XCTAssertEqual(array2.amf0Value, expectedData)
  }
  
  func testEncoder() {
    
    // Number
    XCTAssertEqual(encoder.encode(123), Data([0x00, 0x40, 0x5E, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00]))
    XCTAssertEqual(encoder.encode(3.14), Data([0x00, 0x40, 0x09, 0x1E, 0xB8, 0x51, 0xEB, 0x85, 0x1F]))
    
    // Boolean
    XCTAssertEqual(encoder.encode(true), Data([0x01, 0x01]))
    XCTAssertEqual(encoder.encode(false), Data([0x01, 0x00]))
    
    // String
    XCTAssertEqual(encoder.encode("hello"), Data([0x02, 0x00, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]))
    
    // Long String
    let longString = String(repeating: "a", count: Int(UInt16.max) + 1)
    XCTAssertEqual(encoder.encode(longString), Data([0x0c, 0x00, 0x01, 0x00, 0x00] + Array(repeating: 0x61, count: Int(UInt16.max) + 1)))
    
    // Date
    let date = Date(timeIntervalSince1970: 10.12)
    XCTAssertEqual(encoder.encode(date), Data([0x0b, 0x0, 0x0, 0x0, 0x0, 0x0, 0xc4, 0xc3, 0x40, 0x0, 0x0]))
    
    // Objects
    let object = ["name": "John", "age": 30] as [String: Any]
    let expectedObjectData1 = Data([0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x03, 0x61, 0x67, 0x65, 0x00, 0x40, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09])
    let expectedObjectData2 = Data([0x03, 0x00, 0x03, 0x61, 0x67, 0x65, 0x00, 0x40, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x00, 0x09])

    let data = encoder.encode(object)
    XCTAssert(data == expectedObjectData1 || data == expectedObjectData2)

    // Simple array with Int, String, and Double values
    let array: [Any] = [1, "two", 3.0]
    XCTAssertEqual(encoder.encode(array), Data([0x0A, 0x00, 0x00, 0x00, 0x03, 0x00, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x74, 0x77, 0x6F, 0x00, 0x40, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))

    // Array of dictionaries
    let dict1: [String: Any] = ["name": "John"]
    let dict2: [String: Any] = ["name": "Jane"]
    let array2 = [dict1, dict2]

    let expectedData = Data([0x0A, 0x00, 0x00, 0x00, 0x02, 0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x6F, 0x68, 0x6E, 0x00, 0x00, 0x09, 0x03, 0x00, 0x04, 0x6E, 0x61, 0x6D, 0x65, 0x02, 0x00, 0x04, 0x4A, 0x61, 0x6E, 0x65, 0x00, 0x00, 0x09])
    XCTAssertEqual(encoder.encode(array2), expectedData)
  }

    // MARK: - Encoder Specific Tests

    func testEncodeInt() throws {
        let value: Int = 42
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeDouble() throws {
        let value: Double = 3.14159
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
        XCTAssertEqual(data?.count, 9)
    }

    func testEncodeBoolTrue() throws {
        let data = encoder.encode(true)
        XCTAssertNotNil(data)
        XCTAssertEqual(data, Data([0x01, 0x01]))
    }

    func testEncodeBoolFalse() throws {
        let data = encoder.encode(false)
        XCTAssertNotNil(data)
        XCTAssertEqual(data, Data([0x01, 0x00]))
    }

    func testEncodeString() throws {
        let value = "test"
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x02) // string marker
    }

    func testEncodeEmptyString() throws {
        let value = ""
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x02) // string marker
        XCTAssertEqual(data?.count, 3) // marker + 2 bytes length
    }

    func testEncodeDate() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let data = encoder.encode(date)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x0b) // date marker
        XCTAssertEqual(data?.count, 11)
    }

    func testEncodeArrayGeneric() throws {
        let array: [Any] = [1, 2, 3]
        let data = encoder.encode(array)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x0a) // strict array marker
    }

    func testEncodeEmptyArray() throws {
        let array: [Any] = []
        let data = encoder.encode(array)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x0a) // strict array marker
    }

    func testEncodeDictionary() throws {
        let dict: [String: Any] = ["key": "value"]
        let data = encoder.encode(dict)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x03) // object marker
    }

    func testEncodeEmptyDictionary() throws {
        let dict: [String: Any] = [:]
        let data = encoder.encode(dict)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x03) // object marker
    }

    func testEncodeNil() throws {
        let data = encoder.encodeNil()
        XCTAssertEqual(data, Data([0x05])) // null marker
    }

    // MARK: - Type Coercion Tests

    func testEncodeInt8() throws {
        let value: Int8 = 100
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeInt16() throws {
        let value: Int16 = 1000
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeInt32() throws {
        let value: Int32 = 100000
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeUInt() throws {
        let value: UInt = 42
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeUInt8() throws {
        let value: UInt8 = 255
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    func testEncodeFloat() throws {
        let value: Float = 3.14
        let data = encoder.encode(value)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x00) // number marker
    }

    // MARK: - Round Trip Tests with Encoder

    func testEncoderRoundTripNumber() throws {
        let original: Double = 987.654
        let encoded = encoder.encode(original)
        XCTAssertNotNil(encoded)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(encoded!)
        XCTAssertEqual(decoded?.first?.doubleValue, original)
    }

    func testEncoderRoundTripString() throws {
        let original = "Hello AMF0"
        let encoded = encoder.encode(original)
        XCTAssertNotNil(encoded)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(encoded!)
        XCTAssertEqual(decoded?.first?.stringValue, original)
    }

    func testEncoderRoundTripBool() throws {
        let originalTrue = true
        let encodedTrue = encoder.encode(originalTrue)
        XCTAssertNotNil(encodedTrue)

        let decoder = AMF0Decoder()
        let decodedTrue = decoder.decode(encodedTrue!)
        XCTAssertEqual(decodedTrue?.first?.boolValue, true)
    }

    func testEncoderRoundTripDate() throws {
        let original = Date(timeIntervalSince1970: 1234567890)
        let encoded = encoder.encode(original)
        XCTAssertNotNil(encoded)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(encoded!)
        XCTAssertEqual(decoded?.first?.dateValue, original)
    }

    func testEncoderRoundTripArray() throws {
        let original: [Any] = [1, "two", 3.0]
        let encoded = encoder.encode(original)
        XCTAssertNotNil(encoded)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(encoded!)
        let resultArray = decoded?.first?.toAny() as? [Any]
        XCTAssertEqual(resultArray?.count, 3)
    }

    func testEncoderRoundTripDictionary() throws {
        let original: [String: Any] = ["name": "Test", "value": 42]
        let encoded = encoder.encode(original)
        XCTAssertNotNil(encoded)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(encoded!)
        let result = decoded?.first?.toAny() as? [String: Any]
        XCTAssertEqual(result?["name"] as? String, "Test")
        XCTAssertEqual(result?["value"] as? Double, 42)
    }

    // MARK: - Edge Cases

    func testEncodeVeryLongString() throws {
        let longString = String(repeating: "x", count: 100000)
        let data = encoder.encode(longString)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x0c) // long string marker
    }

    func testEncodeUnicodeString() throws {
        let unicode = "你好🌍"
        let data = encoder.encode(unicode)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x02) // string marker

        // Round trip to verify
        let decoder = AMF0Decoder()
        let decoded = decoder.decode(data!)
        XCTAssertEqual(decoded?.first?.stringValue, unicode)
    }

    func testEncodeNestedStructures() throws {
        let inner: [String: Any] = ["inner": "value"]
        let outer: [String: Any] = ["outer": inner, "number": 42]
        let data = encoder.encode(outer)
        XCTAssertNotNil(data)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(data!)
        let result = decoded?.first?.toAny() as? [String: Any]
        XCTAssertNotNil(result)
    }

    func testEncodeLargeArray() throws {
        let array = Array(repeating: 1, count: 1000)
        let data = encoder.encode(array)
        XCTAssertNotNil(data)
        XCTAssertEqual(data?[0], 0x0a) // strict array marker
    }

    func testEncodeNegativeNumbers() throws {
        let negative: Double = -999.999
        let data = encoder.encode(negative)
        XCTAssertNotNil(data)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(data!)
        XCTAssertEqual(decoded?.first?.doubleValue, negative)
    }

    func testEncodeZero() throws {
        let zero: Double = 0.0
        let data = encoder.encode(zero)
        XCTAssertNotNil(data)

        let decoder = AMF0Decoder()
        let decoded = decoder.decode(data!)
        XCTAssertEqual(decoded?.first?.doubleValue, 0.0)
    }
}
