//
//  AMF0DecoderTests.swift
//
//
//  Created by 郭 輝平 on 2023/03/28.
//

import XCTest
@testable import HPRTMP

final class AMF0DecoderTests: XCTestCase {

    var decoder: AMF0Decoder!

    override func setUpWithError() throws {
        decoder = AMF0Decoder()
    }

    override func tearDownWithError() throws {
        decoder = nil
    }

    // MARK: - Number Decoding

    func testDecodeNumber() {
        let data = 123.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.doubleValue, 123)
    }

    func testEncodeDecodeNumber() {
        let number = 123.45
        let data = number.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.doubleValue, number)
    }

    func testDecodeZero() throws {
        let data = Double(0).amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.doubleValue, 0)
    }

    func testDecodeNegativeNumber() throws {
        let data = Double(-456.789).amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.doubleValue, -456.789)
    }

    func testDecodeLargeNumber() throws {
        let value = 1.7976931348623157e+308
        let data = Double(value).amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.doubleValue, value)
    }

    // MARK: - Boolean Decoding

    func testEncodeDecodeBoolean() {
        let boolean = true
        let data = boolean.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.boolValue, boolean)
    }

    func testDecodeFalse() throws {
        let data = false.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.boolValue, false)
    }

    // MARK: - String Decoding

    func testEncodeDecodeString() {
        let string = "Hello, world!"
        let data = string.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, string)
    }

    func testDecodeEmptyString() throws {
        let data = "".amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, "")
    }

    func testDecodeUnicodeString() throws {
        let string = "你好世界🌍"
        let data = string.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, string)
    }

    func testEncodeDecodeLongString() {
        let longString = String(repeating: "a", count: Int(UInt16.max) + 1)
        let data = longString.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, longString)
    }

    func testDecodeMaxShortString() throws {
        let string = String(repeating: "a", count: Int(UInt16.max))
        let data = string.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, string)
    }

    // MARK: - Null Decoding

    func testEncodeDecodeNull() {
        let data = Data([0x05])
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, "null")
    }

    // MARK: - XML Decoding

    func testEncodeDecodeXML() {
        let xml = "<foo>bar</foo>"
        let data = xml.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, xml)
    }

    func testDecodeComplexXML() throws {
        let xml = "<root><item id=\"1\">value</item><item id=\"2\">value2</item></root>"
        var data = Data([0x0f])
        let utf8Data = Data(xml.utf8)
        data.append(UInt32(utf8Data.count).bigEndian.data)
        data.append(utf8Data)

        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.stringValue, xml)
    }

    // MARK: - Date Decoding

    func testEncodeDecodeDate() {
        let date = Date(timeIntervalSince1970: 1234567890)
        let data = date.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.dateValue, date)
    }

    func testDecodeEpochDate() throws {
        let date = Date(timeIntervalSince1970: 0)
        let data = date.amf0Value
        let result = decoder.decode(data)
        XCTAssertEqual(result?.first?.dateValue, date)
    }

    func testDecodeRecentDate() throws {
        let date = Date()
        let data = date.amf0Value
        let result = decoder.decode(data)
        XCTAssertNotNil(result?.first?.dateValue)
        // Allow millisecond precision tolerance
        XCTAssertEqual(result?.first?.dateValue?.timeIntervalSince1970 ?? 0,
                      date.timeIntervalSince1970,
                      accuracy: 0.001)
    }

    // MARK: - Object Decoding

    func testEncodeDecodeObject() {
        let object: [String: Any] = ["foo": "bar", "baz": 123]
        let data = object.afm0Value
        let result = decoder.decode(data)

        let dic = result?.first?.toAny() as? [String: Any]
        XCTAssertEqual(dic?["foo"] as! String, "bar")
        XCTAssertEqual(dic?["baz"] as! Double, 123)
    }

    func testDecodeEmptyObject() throws {
        let object: [String: Any] = [:]
        let data = object.afm0Value
        let result = decoder.decode(data)

        let dic = result?.first?.toAny() as? [String: Any]
        XCTAssertNotNil(dic)
        XCTAssertEqual(dic?.count, 0)
    }

    func testDecodeNestedObject() throws {
        // Note: [String: Any] dictionary values don't conform to AMF0Encodable
        // so nested dictionaries are encoded as null
        let inner: [String: Any] = ["inner": "value"]
        let outer: [String: Any] = ["outer": inner]
        let data = outer.afm0Value
        let result = decoder.decode(data)

        let dic = result?.first?.toAny() as? [String: Any]
        // Inner dictionary is encoded as null, toAny() returns string "null"
        XCTAssertEqual(dic?["outer"] as? String, "null")
    }

    // MARK: - Array Decoding

    func testEncodeDecodeArray() {
        let array = ["foo", "bar", 123] as [Any]
        let data = array.amf0Value
        let result = decoder.decode(data)
        let resultArray = result?.first?.toAny() as? [Any]
        XCTAssertEqual(resultArray?.first as? String, "foo")
        XCTAssertEqual(resultArray?[1] as? String, "bar")
        XCTAssertEqual(resultArray?[2] as? Double, 123)
    }

    func testDecodeEmptyArray() throws {
        let array: [Any] = []
        let data = array.amf0Value
        let result = decoder.decode(data)
        let resultArray = result?.first?.toAny() as? [Any]
        XCTAssertNotNil(resultArray)
        XCTAssertEqual(resultArray?.count, 0)
    }

    func testDecodeArrayOfObjects() throws {
        let dict1: [String: Any] = ["name": "John"]
        let dict2: [String: Any] = ["name": "Jane"]
        let array = [dict1, dict2]
        let data = array.amf0Value
        let result = decoder.decode(data)

        let resultArray = result?.first?.toAny() as? [Any]
        XCTAssertEqual(resultArray?.count, 2)
    }

    func testDecodeHomogeneousArray() throws {
        let array = [1, 2, 3, 4, 5] as [Any]
        let data = array.amf0Value
        let result = decoder.decode(data)
        let resultArray = result?.first?.toAny() as? [Any]
        XCTAssertEqual(resultArray?.count, 5)
        XCTAssertEqual(resultArray?[0] as? Double, 1)
        XCTAssertEqual(resultArray?[4] as? Double, 5)
    }

    // MARK: - Multiple Values

    func testDecodeMultipleValues() throws {
        var data = Data()
        data.append(123.amf0Value)
        data.append("test".amf0Value)
        data.append(true.amf0Value)

        let result = decoder.decode(data)
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].doubleValue, 123)
        XCTAssertEqual(result?[1].stringValue, "test")
        XCTAssertEqual(result?[2].boolValue, true)
    }

    // MARK: - Error Cases

    func testDecodeIncompleteNumber() throws {
        let data = Data([0x00, 0x01, 0x02])
        let result = decoder.decode(data)
        XCTAssertNil(result)
    }

    func testDecodeInvalidType() throws {
        let data = Data([0xFF])
        let result = decoder.decode(data)
        XCTAssertTrue(result?.isEmpty ?? true)
    }

    func testDecodeIncompleteString() throws {
        var data = Data([0x02])
        data.append(UInt16(100).bigEndian.data)
        data.append(Data(repeating: 0x61, count: 50))

        let result = decoder.decode(data)
        XCTAssertNil(result)
    }

    func testDecodeTruncatedObject() throws {
        var data = Data([0x03])
        data.append(UInt16(3).bigEndian.data)
        data.append(Data("key".utf8))

        let result = decoder.decode(data)
        XCTAssertNil(result)
    }

    // MARK: - Extension Tests

    func testDataDecodeAMF0Extension() throws {
        let data = 123.amf0Value
        let result = data.decodeAMF0()
        XCTAssertEqual(result?.first?.doubleValue, 123)
    }

    func testDecodeAMF0MultipleTypes() throws {
        var data = Data()
        data.append(Double(3.14).amf0Value)
        data.append("hello".amf0Value)
        data.append(false.amf0Value)

        let result = data.decodeAMF0()
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].doubleValue, 3.14)
        XCTAssertEqual(result?[1].stringValue, "hello")
        XCTAssertEqual(result?[2].boolValue, false)
    }

    // MARK: - Round Trip Tests

    func testRoundTripNumber() throws {
        let original: Double = 987.654
        let encoded = original.amf0Value
        let decoded = decoder.decode(encoded)
        XCTAssertEqual(decoded?.first?.doubleValue, original)
    }

    func testRoundTripString() throws {
        let original = "Test String 测试"
        let encoded = original.amf0Value
        let decoded = decoder.decode(encoded)
        XCTAssertEqual(decoded?.first?.stringValue, original)
    }

    func testRoundTripBool() throws {
        let originalTrue = true
        let encodedTrue = originalTrue.amf0Value
        let decodedTrue = decoder.decode(encodedTrue)
        XCTAssertEqual(decodedTrue?.first?.boolValue, true)

        let originalFalse = false
        let encodedFalse = originalFalse.amf0Value
        let decodedFalse = decoder.decode(encodedFalse)
        XCTAssertEqual(decodedFalse?.first?.boolValue, false)
    }

    func testRoundTripDate() throws {
        let original = Date(timeIntervalSince1970: 1609459200.123)
        let encoded = original.amf0Value
        let decoded = decoder.decode(encoded)
        XCTAssertEqual(decoded?.first?.dateValue?.timeIntervalSince1970 ?? 0,
                      original.timeIntervalSince1970,
                      accuracy: 0.001)
    }

    func testRoundTripComplexObject() throws {
        let original: [String: Any] = [
            "name": "John Doe",
            "age": 30,
            "active": true
        ]
        let encoded = original.afm0Value
        let decoded = decoder.decode(encoded)
        let result = decoded?.first?.toAny() as? [String: Any]

        XCTAssertEqual(result?["name"] as? String, "John Doe")
        XCTAssertEqual(result?["age"] as? Double, 30)
        XCTAssertEqual(result?["active"] as? Bool, true)
    }
}
