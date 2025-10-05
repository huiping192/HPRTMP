//
//  AMF3ObjectTests.swift
//
//
//  Created by AMF3 Test Suite
//

import XCTest
@testable import HPRTMP

final class AMF3ObjectTests: XCTestCase {

    var amf3Object: AMF3Object!

    override func setUpWithError() throws {
        amf3Object = AMF3Object()
    }

    override func tearDownWithError() throws {
        amf3Object = nil
    }

    // MARK: - Append Basic Types

    func testAppendUndefined() throws {
        amf3Object.appendUndefined()

        XCTAssertEqual(amf3Object.data.count, 1)
        XCTAssertEqual(amf3Object.data[0], 0x00)
    }

    func testAppendNil() throws {
        amf3Object.appendNil()

        XCTAssertEqual(amf3Object.data.count, 1)
        XCTAssertEqual(amf3Object.data[0], 0x01)
    }

    func testAppendBool() throws {
        amf3Object.appned(true)
        XCTAssertEqual(amf3Object.data[0], 0x03)

        amf3Object = AMF3Object()
        amf3Object.appned(false)
        XCTAssertEqual(amf3Object.data[0], 0x02)
    }

    func testAppendInt() throws {
        let value = 123
        amf3Object.append(value)

        XCTAssertTrue(amf3Object.data.count >= 2)
        XCTAssertEqual(amf3Object.data[0], 0x04) // int marker
    }

    func testAppendDouble() throws {
        let value: Double = 3.14159
        amf3Object.append(value)

        XCTAssertEqual(amf3Object.data.count, 9) // 1 marker + 8 bytes
        XCTAssertEqual(amf3Object.data[0], 0x05) // double marker
    }

    func testAppendString() throws {
        let value = "test"
        amf3Object.append(value)

        XCTAssertTrue(amf3Object.data.count > 2)
        XCTAssertEqual(amf3Object.data[0], 0x06) // string marker
    }

    func testAppendEmptyString() throws {
        let value = ""
        amf3Object.append(value)

        XCTAssertEqual(amf3Object.data.count, 2)
        XCTAssertEqual(amf3Object.data[0], 0x06) // string marker
        XCTAssertEqual(amf3Object.data[1], 0x01) // empty string length
    }

    func testAppendXML() throws {
        let xml = "<root><child>value</child></root>"
        amf3Object.appendXML(xml)

        XCTAssertTrue(amf3Object.data.count > 0)
        // XML should use the string encoding
        XCTAssertEqual(amf3Object.data[0], 0x06) // string marker (XML uses string encoding in this implementation)
    }

    func testAppendDate() throws {
        let date = Date()
        amf3Object.append(date)

        XCTAssertEqual(amf3Object.data.count, 10)
        XCTAssertEqual(amf3Object.data[0], 0x08) // date marker
    }

    func testAppendArray() throws {
        let array: [Any] = [123, "test"]
        amf3Object.append(array)

        XCTAssertTrue(amf3Object.data.count > 0)
        XCTAssertEqual(amf3Object.data[0], 0x09) // array marker
    }

    func testAppendEmptyArray() throws {
        let array: [Any] = []
        amf3Object.append(array)

        XCTAssertEqual(amf3Object.data[0], 0x09) // array marker
        XCTAssertEqual(amf3Object.data[1], 0x01) // empty length
    }

    func testAppendDictionary() throws {
        let dict: [String: Any?] = ["key": "value"]
        amf3Object.append(dict)

        XCTAssertTrue(amf3Object.data.count > 0)
        XCTAssertEqual(amf3Object.data[0], 0x0a) // object marker
    }

    func testAppendNilDictionary() throws {
        let dict: [String: Any?]? = nil
        amf3Object.append(dict)

        XCTAssertEqual(amf3Object.data.count, 0) // nil dictionary should not append anything
    }

    func testAppendByteArray() throws {
        let bytes = Data([0x01, 0x02, 0x03])
        amf3Object.appendByteArray(bytes)

        XCTAssertTrue(amf3Object.data.count > 3)
        XCTAssertEqual(amf3Object.data[0], 0x0c) // byte array marker
    }

    func testAppendVectorInt() throws {
        let vector: [Int32] = [1, 2, 3]
        amf3Object.appendVector(vector)

        XCTAssertTrue(amf3Object.data.count > 0)
        XCTAssertEqual(amf3Object.data[0], 0x0d) // vector int marker
    }

    func testAppendVectorUInt() throws {
        let vector: [UInt32] = [10, 20, 30]
        amf3Object.appendVector(vector)

        XCTAssertTrue(amf3Object.data.count > 0)
        XCTAssertEqual(amf3Object.data[0], 0x0e) // vector uint marker
    }

    func testAppendVectorDouble() throws {
        let vector: [Double] = [1.1, 2.2, 3.3]
        amf3Object.appendVector(vector)

        XCTAssertTrue(amf3Object.data.count > 0)
        XCTAssertEqual(amf3Object.data[0], 0x0f) // vector double marker
    }

    // MARK: - Multiple Appends

    func testMultipleAppends() throws {
        amf3Object.append(123)
        amf3Object.append("test")
        amf3Object.appned(true)

        XCTAssertTrue(amf3Object.data.count > 5)

        XCTAssertEqual(amf3Object.data[0], 0x04)
    }

    func testMixedTypeAppends() throws {
        amf3Object.appendUndefined()
        amf3Object.appendNil()
        amf3Object.append(42)
        amf3Object.append("hello")
        amf3Object.appned(false)

        XCTAssertTrue(amf3Object.data.count > 5)

        XCTAssertEqual(amf3Object.data[0], 0x00)
    }

    // MARK: - Decode Tests

    func testDecodeSimpleValue() throws {
        amf3Object.append(123)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 1)

        if let decoded = decoded, case .int(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, 123)
        }
    }

    func testDecodeMultipleValues() throws {
        amf3Object.append(123)
        amf3Object.append("test")
        amf3Object.appned(true)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 3)
    }

    func testStaticDecode() throws {
        let data = Data([0x04, 0x7b])

        let decoded = AMF3Object.decode(data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 1)

        if let decoded = decoded, case .int(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, 123)
        }
    }

    // MARK: - Round Trip Tests

    func testRoundTripInt() throws {
        let original = 12345
        amf3Object.append(original)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .int(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed round trip for int")
        }
    }

    func testRoundTripString() throws {
        let original = "Hello, World!"
        amf3Object.append(original)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .string(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed round trip for string")
        }
    }

    func testRoundTripDouble() throws {
        let original: Double = 3.14159265359
        amf3Object.append(original)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .double(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, original, accuracy: 0.0000001)
        } else {
            XCTFail("Failed round trip for double")
        }
    }

    func testRoundTripBool() throws {
        amf3Object.appned(true)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .bool(let value) = decoded[0] as? AMFValue {
            XCTAssertTrue(value)
        } else {
            XCTFail("Failed round trip for bool")
        }
    }

    func testRoundTripByteArray() throws {
        let original = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        amf3Object.appendByteArray(original)

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .byteArray(let value) = decoded[0] as? AMFValue {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed round trip for byte array")
        }
    }

    // MARK: - Complex Scenarios

    func testComplexObject() throws {
        amf3Object.append(123)
        amf3Object.append("name")
        amf3Object.appned(true)
        amf3Object.append(3.14)
        amf3Object.appendByteArray(Data([0x01, 0x02]))

        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 5)
    }

    func testEmptyObject() throws {
        let decoded = amf3Object.decode()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 0)
    }

    // MARK: - Data Property Tests

    func testDataProperty() throws {
        XCTAssertEqual(amf3Object.data.count, 0)

        amf3Object.append(123)
        XCTAssertTrue(amf3Object.data.count > 0)

        let dataSnapshot = amf3Object.data
        amf3Object.append("test")
        XCTAssertTrue(amf3Object.data.count > dataSnapshot.count)
    }
}
