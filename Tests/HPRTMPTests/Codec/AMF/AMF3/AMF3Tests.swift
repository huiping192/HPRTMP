//
//  AMF3Tests.swift
//
//
//  Created by 郭 輝平 on 2023/03/27.
//

import XCTest
@testable import HPRTMP

final class AMF3Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Bool AMF3Encodable Tests

    func testBoolTrueEncoding() throws {
        let value = true
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x03]))
    }

    func testBoolFalseEncoding() throws {
        let value = false
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x02]))
    }

    // MARK: - Int AMF3Encodable Tests

    func testIntSmallValueEncoding() throws {
        let value = 123
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x04, 0x7b]))
    }

    func testIntZeroEncoding() throws {
        let value = 0
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x04, 0x00]))
    }

    func testIntMaxSmallValueEncoding() throws {
        let value = 0x7f
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x04, 0x7f]))
    }

    func testIntMediumValueEncoding() throws {
        let value = 0x80
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x04, 0x81, 0x00]))
    }

    func testIntLargeValueEncoding() throws {
        let value = 0x4000
        let data = value.amf3Value
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data[0], 0x04)
    }

    func testIntVeryLargeValueEncoding() throws {
        let value = 0x200000
        let data = value.amf3Value
        XCTAssertEqual(data.count, 5)
        XCTAssertEqual(data[0], 0x04)
    }

    func testIntOutOfRangeConvertToDouble() throws {
        // Values outside AMF3 int range should convert to double
        let value = 0x20000000
        let data = value.amf3Value
        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)
    }

    func testIntLengthConvert() throws {
        let value1 = 5
        let lengthData1 = value1.amf3LengthConvert
        XCTAssertEqual(lengthData1, Data([0x05]))

        let value2 = 128
        let lengthData2 = value2.amf3LengthConvert
        XCTAssertEqual(lengthData2.count, 2)
    }

    // MARK: - Double AMF3Encodable Tests

    func testDoubleEncoding() throws {
        let value: Double = 3.14159265359
        let data = value.amf3Value

        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)

        // Verify can be decoded back
        let encodedBytes = data.dropFirst()
        let reversed = Data(encodedBytes.reversed())
        let decoded = reversed.withUnsafeBytes { $0.load(as: Double.self) }
        XCTAssertEqual(decoded, value, accuracy: 0.0000001)
    }

    func testDoubleZeroEncoding() throws {
        let value: Double = 0.0
        let data = value.amf3Value
        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)
    }

    func testDoubleNegativeEncoding() throws {
        let value: Double = -123.456
        let data = value.amf3Value
        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)
    }

    func testDoubleLargeValueEncoding() throws {
        let value: Double = 1.7976931348623157e+308
        let data = value.amf3Value
        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)
    }

    // MARK: - String AMF3Encodable Tests

    func testStringEncoding() throws {
        let value = "hello"
        let data = value.amf3Value

        XCTAssertEqual(data[0], 0x06)

        XCTAssertEqual(data[1], 0x0b)

        let stringData = data.dropFirst(2)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), value)
    }

    func testEmptyStringEncoding() throws {
        let value = ""
        let data = value.amf3Value

        XCTAssertEqual(data[0], 0x06)
        XCTAssertEqual(data[1], 0x01)
        XCTAssertEqual(data.count, 2)
    }

    func testStringKeyValueEncoding() throws {
        let value = "test"
        let data = value.amf3KeyValue

        XCTAssertEqual(data[0], 0x09)

        let stringData = data.dropFirst(1)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), value)
    }

    func testStringUnicodeEncoding() throws {
        let value = "你好世界"
        let data = value.amf3Value

        XCTAssertEqual(data[0], 0x06)

        let utf8Count = value.utf8.count
        let expectedLength = (utf8Count << 1) | 0x01

        XCTAssertEqual(data[1], UInt8(expectedLength))
    }

    func testStringLongValueEncoding() throws {
        let value = String(repeating: "a", count: 1000)
        let data = value.amf3Value

        XCTAssertEqual(data[0], 0x06) // string marker
        XCTAssertTrue(data.count > 1000)
    }

    // MARK: - Date AMF3Encodable Tests

    func testDateEncoding() throws {
        let date = Date()
        let data = date.amf3Value

        XCTAssertEqual(data[0], 0x08)
        XCTAssertEqual(data[1], 0x01)
        XCTAssertEqual(data.count, 10)
    }

    func testDateSpecificValueEncoding() throws {
        let date = Date(timeIntervalSince1970: 1234567890.0)
        let data = date.amf3Value

        XCTAssertEqual(data[0], 0x08)
        XCTAssertEqual(data[1], 0x01)

        // Verify milliseconds
        let milliseconds = date.timeIntervalSince1970 * 1000
        let milliData = data.dropFirst(2)
        let reversed = Data(milliData.reversed())
        let decoded = reversed.withUnsafeBytes { $0.load(as: Double.self) }
        XCTAssertEqual(decoded, milliseconds, accuracy: 0.001)
    }

    // MARK: - Array AMF3Encodable Tests

    func testArrayEncoding() throws {
        let array: [Int] = [1, 2, 3]
        let data = array.amf3Value

        XCTAssertEqual(data[0], 0x09)

        XCTAssertEqual(data[1], 0x07)
    }

    func testEmptyArrayEncoding() throws {
        let array: [Int] = []
        let data = array.amf3Value

        XCTAssertEqual(data[0], 0x09)
        XCTAssertEqual(data[1], 0x01)
    }

    func testMixedArrayEncoding() throws {
        let array: [Any] = [123, "test", true]
        let data = array.amf3Value

        XCTAssertEqual(data[0], 0x09)

        XCTAssertEqual(data[1], 0x07)
    }

    // MARK: - Dictionary AMF3Encodable Tests

    func testDictionaryEncoding() throws {
        let dict: [String: Any?] = ["key1": "value1", "key2": 123]
        let data = dict.amf3Value

        XCTAssertEqual(data[0], 0x0a)
        XCTAssertTrue(data.count > 3)
    }

    func testEmptyDictionaryEncoding() throws {
        let dict: [String: Any?] = [:]
        let data = dict.amf3Value

        XCTAssertEqual(data[0], 0x0a)
    }

    func testDictionaryWithNullValues() throws {
        let dict: [String: Any?] = ["key1": nil, "key2": "value"]
        let data = dict.amf3Value

        XCTAssertEqual(data[0], 0x0a)
    }

    // MARK: - ByteArray AMF3ByteArrayEncodable Tests

    func testByteArrayEncoding() throws {
        let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let data = bytes.amf3ByteValue

        XCTAssertEqual(data[0], 0x0c)

        XCTAssertEqual(data[1], 0x0b)

        let byteData = data.dropFirst(2)
        XCTAssertEqual(byteData, bytes)
    }

    func testEmptyByteArrayEncoding() throws {
        let bytes = Data()
        let data = bytes.amf3ByteValue

        XCTAssertEqual(data[0], 0x0c)
        XCTAssertEqual(data[1], 0x01)
        XCTAssertEqual(data.count, 2)
    }

    func testLargeByteArrayEncoding() throws {
        let bytes = Data(repeating: 0xff, count: 1000)
        let data = bytes.amf3ByteValue

        XCTAssertEqual(data[0], 0x0c) // byte array marker
        XCTAssertTrue(data.count > 1000)
    }

    // MARK: - Vector AMF3VectorEncodable Tests

    func testVectorIntEncoding() throws {
        let vector: [Int32] = [1, 2, 3]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0d)

        XCTAssertEqual(data[1], 0x07)
        XCTAssertEqual(data[2], 0x00)
    }

    func testVectorUIntEncoding() throws {
        let vector: [UInt32] = [10, 20, 30]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0e)

        XCTAssertEqual(data[1], 0x07)
        XCTAssertEqual(data[2], 0x00)
    }

    func testVectorDoubleEncoding() throws {
        let vector: [Double] = [1.1, 2.2, 3.3]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0f)

        XCTAssertEqual(data[1], 0x07)
        XCTAssertEqual(data[2], 0x00)
    }

    func testEmptyVectorIntEncoding() throws {
        let vector: [Int32] = []
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0d)
        XCTAssertEqual(data[1], 0x01)
    }

    func testEmptyVectorUIntEncoding() throws {
        let vector: [UInt32] = []
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0e)
        XCTAssertEqual(data[1], 0x01)
    }

    func testEmptyVectorDoubleEncoding() throws {
        let vector: [Double] = []
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0f)
        XCTAssertEqual(data[1], 0x01)
    }

    // MARK: - AMF3EncodeType Tests

    func testU29ValueType() throws {
        let valueType = AMF3EncodeType.U29.value
        XCTAssertEqual(valueType.rawValue, 0x01)
    }

    func testU29ReferenceType() throws {
        let refType = AMF3EncodeType.U29.reference
        XCTAssertEqual(refType.rawValue, 0x00)
    }

    func testU29TypeInitialization() throws {
        let value = AMF3EncodeType.U29(rawValue: 0x01)
        XCTAssertEqual(value, .value)

        let reference = AMF3EncodeType.U29(rawValue: 0x00)
        XCTAssertEqual(reference, .reference)

        let invalid = AMF3EncodeType.U29(rawValue: 0x02)
        XCTAssertNil(invalid)
    }

    func testVectorType() throws {
        let fix = AMF3EncodeType.Vector.fix
        XCTAssertEqual(fix.rawValue, 0x01)

        let dynamic = AMF3EncodeType.Vector.dynamic
        XCTAssertEqual(dynamic.rawValue, 0x00)
    }

    // MARK: - RTMPAMF3Type Tests

    func testRTMPAMF3TypeRawValues() throws {
        XCTAssertEqual(RTMPAMF3Type.undefined.rawValue, 0x00)
        XCTAssertEqual(RTMPAMF3Type.null.rawValue, 0x01)
        XCTAssertEqual(RTMPAMF3Type.boolFalse.rawValue, 0x02)
        XCTAssertEqual(RTMPAMF3Type.boolTrue.rawValue, 0x03)
        XCTAssertEqual(RTMPAMF3Type.int.rawValue, 0x04)
        XCTAssertEqual(RTMPAMF3Type.double.rawValue, 0x05)
        XCTAssertEqual(RTMPAMF3Type.string.rawValue, 0x06)
        XCTAssertEqual(RTMPAMF3Type.xml.rawValue, 0x07)
        XCTAssertEqual(RTMPAMF3Type.date.rawValue, 0x08)
        XCTAssertEqual(RTMPAMF3Type.array.rawValue, 0x09)
        XCTAssertEqual(RTMPAMF3Type.object.rawValue, 0x0a)
        XCTAssertEqual(RTMPAMF3Type.xmlEnd.rawValue, 0x0b)
        XCTAssertEqual(RTMPAMF3Type.byteArray.rawValue, 0x0c)
        XCTAssertEqual(RTMPAMF3Type.vectorInt.rawValue, 0x0d)
        XCTAssertEqual(RTMPAMF3Type.vectorUInt.rawValue, 0x0e)
        XCTAssertEqual(RTMPAMF3Type.vectorDouble.rawValue, 0x0f)
        XCTAssertEqual(RTMPAMF3Type.vectorObject.rawValue, 0x10)
        XCTAssertEqual(RTMPAMF3Type.dictionary.rawValue, 0x11)
    }

    func testRTMPAMF3TypeInitialization() throws {
        XCTAssertNotNil(RTMPAMF3Type(rawValue: 0x00))
        XCTAssertNotNil(RTMPAMF3Type(rawValue: 0x11))
        XCTAssertNil(RTMPAMF3Type(rawValue: 0xFF))
    }
}
