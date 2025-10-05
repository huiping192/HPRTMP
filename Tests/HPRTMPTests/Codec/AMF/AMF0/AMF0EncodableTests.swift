//
//  AMF0EncodableTests.swift
//
//
//  Created by AMF0 Test Suite
//

import XCTest
@testable import HPRTMP

final class AMF0EncodableTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Integer Types Encoding

    func testIntEncoding() throws {
        let value: Int = 123
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testInt8Encoding() throws {
        let value: Int8 = 42
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testInt16Encoding() throws {
        let value: Int16 = 1000
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testInt32Encoding() throws {
        let value: Int32 = 100000
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testUIntEncoding() throws {
        let value: UInt = 456
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testUInt8Encoding() throws {
        let value: UInt8 = 255
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testUInt16Encoding() throws {
        let value: UInt16 = 65535
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testUInt32Encoding() throws {
        let value: UInt32 = 4294967295
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testFloatEncoding() throws {
        let value: Float = 3.14
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    // MARK: - Double Encoding

    func testDoubleEncoding() throws {
        let value: Double = 123.45
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)

        // Verify big endian encoding
        let doubleBytes = data.subdata(in: 1..<9)
        let decoded = doubleBytes.withUnsafeBytes { $0.load(as: UInt64.self) }
        let decodedDouble = Double(bitPattern: decoded.bigEndian)
        XCTAssertEqual(decodedDouble, value, accuracy: 0.0001)
    }

    func testDoubleZeroEncoding() throws {
        let value: Double = 0.0
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testDoubleNegativeEncoding() throws {
        let value: Double = -456.789
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    func testDoubleLargeValueEncoding() throws {
        let value: Double = 1.7976931348623157e+308
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data.count, 9)
    }

    // MARK: - Bool Encoding

    func testBoolTrueEncoding() throws {
        let value = true
        let data = value.amf0Value

        XCTAssertEqual(data, Data([0x01, 0x01]))
    }

    func testBoolFalseEncoding() throws {
        let value = false
        let data = value.amf0Value

        XCTAssertEqual(data, Data([0x01, 0x00]))
    }

    // MARK: - String Encoding

    func testStringShortEncoding() throws {
        let value = "hello"
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x02)

        let lengthBytes = data.subdata(in: 1..<3)
        let length = UInt16(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(length, 5)

        let stringData = data.dropFirst(3)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), value)
    }

    func testStringEmptyEncoding() throws {
        let value = ""
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x02)
        XCTAssertEqual(data.count, 3)
    }

    func testStringUnicodeEncoding() throws {
        let value = "你好世界"
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x02)

        let utf8Count = value.utf8.count
        let lengthBytes = data.subdata(in: 1..<3)
        let length = UInt16(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(Int(length), utf8Count)
    }

    func testStringLongEncoding() throws {
        // String length exceeds UInt16.max, should use long string
        let value = String(repeating: "a", count: Int(UInt16.max) + 1)
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x0c)

        let lengthBytes = data.subdata(in: 1..<5)
        let length = UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(length, UInt32(UInt16.max) + 1)
    }

    func testStringMaxShortEncoding() throws {
        // Exactly UInt16.max, should still use regular string
        let value = String(repeating: "a", count: Int(UInt16.max))
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x02)
    }

    func testStringKeyEncodeShort() throws {
        let value = "key"
        let data = value.amf0KeyEncode

        let lengthBytes = data.subdata(in: 0..<2)
        let length = UInt16(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(length, 3)
        XCTAssertEqual(data.count, 5)
    }

    // MARK: - Date Encoding

    func testDateEncoding() throws {
        let value = Date(timeIntervalSince1970: 1234567890)
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x0b)
        XCTAssertEqual(data.count, 11)

        // Verify timezone offset is 0
        XCTAssertEqual(data[9], 0x00)
        XCTAssertEqual(data[10], 0x00)
    }

    func testDateZeroEncoding() throws {
        let value = Date(timeIntervalSince1970: 0)
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x0b)
        XCTAssertEqual(data.count, 11)
    }

    func testDateNowEncoding() throws {
        let value = Date()
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x0b)
        XCTAssertEqual(data.count, 11)
    }

    // MARK: - Dictionary Encoding (Object)

    func testDictionaryObjectEncoding() throws {
        let dict: [String: Any] = ["key": "value"]
        let data = dict.afm0Value

        XCTAssertEqual(data[0], 0x03)

        // Should end with 0x00 0x00 0x09 (empty string length + object end)
        let endIndex = data.count - 3
        XCTAssertEqual(data[endIndex], 0x00)
        XCTAssertEqual(data[endIndex + 1], 0x00)
        XCTAssertEqual(data[endIndex + 2], 0x09)
    }

    func testDictionaryEmptyEncoding() throws {
        let dict: [String: Any] = [:]
        let data = dict.afm0Value

        XCTAssertEqual(data[0], 0x03)
        XCTAssertEqual(data, Data([0x03, 0x00, 0x00, 0x09]))
    }

    func testDictionaryMultipleKeysEncoding() throws {
        let dict: [String: Any] = ["key1": "value1", "key2": 123]
        let data = dict.afm0Value

        XCTAssertEqual(data[0], 0x03)

        let endIndex = data.count - 3
        XCTAssertEqual(data[endIndex + 2], 0x09)
    }

    func testDictionaryNullValueEncoding() throws {
        let dict: [String: Any?] = ["key": nil]
        let data = dict.afm0Value

        XCTAssertEqual(data[0], 0x03)
        XCTAssertTrue(data.contains(0x05))
    }

    func testDictionaryECMAArrayEncoding() throws {
        let dict: [String: Any] = ["key1": "value1", "key2": 123]
        let data = dict.amf0EcmaArray

        XCTAssertEqual(data[0], 0x08)

        let countBytes = data.subdata(in: 1..<5)
        let count = UInt32(bigEndian: countBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(count, 2)
    }

    // MARK: - Array Encoding (Strict Array)

    func testArrayStrictEncoding() throws {
        let array: [Any] = [1, "two", 3.0]
        let data = array.amf0Value

        XCTAssertEqual(data[0], 0x0a)

        let countBytes = data.subdata(in: 1..<5)
        let count = UInt32(bigEndian: countBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(count, 3)
    }

    func testArrayEmptyEncoding() throws {
        let array: [Any] = []
        let data = array.amf0Value

        XCTAssertEqual(data[0], 0x0a)

        let countBytes = data.subdata(in: 1..<5)
        let count = UInt32(bigEndian: countBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(count, 0)
        XCTAssertEqual(data.count, 5)
    }

    func testArrayWithDictionariesEncoding() throws {
        let dict1: [String: Any] = ["name": "John"]
        let dict2: [String: Any] = ["name": "Jane"]
        let array = [dict1, dict2]
        let data = array.amf0Value

        XCTAssertEqual(data[0], 0x0a)

        let countBytes = data.subdata(in: 1..<5)
        let count = UInt32(bigEndian: countBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(count, 2)

        XCTAssertTrue(data.contains(0x03))
    }

    func testArrayGroupEncoding() throws {
        let array: [Any] = [1, "test", true]
        let data = array.amf0GroupEncode

        // amf0GroupEncode doesn't include array marker, just consecutive values
        XCTAssertNotEqual(data[0], 0x0a)
        XCTAssertEqual(data[0], 0x00)
    }

    // MARK: - RTMPAMF0Type Enum Tests

    func testRTMPAMF0TypeRawValues() throws {
        XCTAssertEqual(RTMPAMF0Type.number.rawValue, 0x00)
        XCTAssertEqual(RTMPAMF0Type.boolean.rawValue, 0x01)
        XCTAssertEqual(RTMPAMF0Type.string.rawValue, 0x02)
        XCTAssertEqual(RTMPAMF0Type.object.rawValue, 0x03)
        XCTAssertEqual(RTMPAMF0Type.null.rawValue, 0x05)
        XCTAssertEqual(RTMPAMF0Type.array.rawValue, 0x08)
        XCTAssertEqual(RTMPAMF0Type.objectEnd.rawValue, 0x09)
        XCTAssertEqual(RTMPAMF0Type.strictArray.rawValue, 0x0a)
        XCTAssertEqual(RTMPAMF0Type.date.rawValue, 0x0b)
        XCTAssertEqual(RTMPAMF0Type.longString.rawValue, 0x0c)
        XCTAssertEqual(RTMPAMF0Type.xml.rawValue, 0x0f)
        XCTAssertEqual(RTMPAMF0Type.typedObject.rawValue, 0x10)
        XCTAssertEqual(RTMPAMF0Type.switchAMF3.rawValue, 0x11)
    }

    // MARK: - Edge Cases

    func testNegativeIntegersConvertToDouble() throws {
        let value: Int = -100
        let data = value.amf0Value

        XCTAssertEqual(data[0], 0x00) // number marker
        XCTAssertEqual(data.count, 9)
    }

    func testVeryLargeArray() throws {
        let array = Array(repeating: 1, count: 1000)
        let data = array.amf0Value

        XCTAssertEqual(data[0], 0x0a) // strict array marker

        let count = UInt32(bigEndian: data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: UInt32.self) })
        XCTAssertEqual(count, 1000)
    }

    func testNestedDictionaries() throws {
        let inner: [String: Any] = ["inner": "value"]
        let outer: [String: Any] = ["outer": inner]
        let data = outer.afm0Value

        XCTAssertEqual(data[0], 0x03)

        // Note: [String: Any] dictionary values don't conform to AMF0Encodable
        // so nested dictionaries are encoded as null (0x05)
        // Byte 0x05 appears twice: 1) key length (0x00 0x05) 2) null marker
        let nullMarkerCount = data.filter { $0 == 0x05 }.count
        XCTAssertEqual(nullMarkerCount, 2)
    }
}
