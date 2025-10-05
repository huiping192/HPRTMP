//
//  AMF3DecoderTests.swift
//
//
//  Created by AMF3 Test Suite
//

import XCTest
@testable import HPRTMP

final class AMF3DecoderTests: XCTestCase {

    var decoder: AMF3Decoder!

    override func setUpWithError() throws {
        decoder = AMF3Decoder()
    }

    override func tearDownWithError() throws {
        decoder = nil
    }

    // MARK: - Basic Types Decoding

    func testDecodeUndefined() throws {
        let data = Data([0x00])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .undefined = result[0] {
            // Success
        } else {
            XCTFail("Expected undefined value")
        }
    }

    func testDecodeNull() throws {
        let data = Data([0x01])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .null = result[0] {
            // Success
        } else {
            XCTFail("Expected null value")
        }
    }

    func testDecodeBoolTrue() throws {
        let data = Data([0x03])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .bool(let value) = result[0] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected bool true value")
        }
    }

    func testDecodeBoolFalse() throws {
        let data = Data([0x02])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .bool(let value) = result[0] {
            XCTAssertFalse(value)
        } else {
            XCTFail("Expected bool false value")
        }
    }

    func testDecodeSmallInt() throws {
        let data = Data([0x04, 0x7b])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .int(let value) = result[0] {
            XCTAssertEqual(value, 123)
        } else {
            XCTFail("Expected int value")
        }
    }

    func testDecodeMediumInt() throws {
        let data = Data([0x04, 0x81, 0x00])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .int(let value) = result[0] {
            XCTAssertEqual(value, 128)
        } else {
            XCTFail("Expected int value")
        }
    }

    func testDecodeDouble() throws {
        let doubleValue: Double = 3.14159265359
        let doubleData = Data(doubleValue.bitPattern.bigEndian.data)
        var data = Data([0x05])
        data.append(doubleData)

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .double(let value) = result[0] {
            XCTAssertEqual(value, doubleValue, accuracy: 0.0000001)
        } else {
            XCTFail("Expected double value")
        }
    }

    func testDecodeString() throws {
        let testString = "hello"
        let length = (testString.count << 1) | 0x01
        var data = Data([0x06])
        data.append(UInt8(length))
        data.append(Data(testString.utf8))

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .string(let value) = result[0] {
            XCTAssertEqual(value, testString)
        } else {
            XCTFail("Expected string value")
        }
    }

    func testDecodeEmptyString() throws {
        let data = Data([0x06, 0x01])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .string(let value) = result[0] {
            XCTAssertEqual(value, "")
        } else {
            XCTFail("Expected empty string")
        }
    }

    func testDecodeDate() throws {
        let date = Date()
        let milliseconds = date.timeIntervalSince1970 * 1000
        let milliData = Data(milliseconds.bitPattern.bigEndian.data)

        var data = Data([0x08, 0x01])
        data.append(milliData)

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .date(let value) = result[0] {
            XCTAssertEqual(value.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("Expected date value")
        }
    }

    // MARK: - Array Decoding

    func testDecodeEmptyArray() throws {
        let data = Data([0x09, 0x01, 0x01])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .array(let array) = result[0] {
            XCTAssertEqual(array.count, 0)
        } else {
            XCTFail("Expected array value")
        }
    }

    func testDecodeSimpleArray() throws {
        let data = Data([0x09, 0x03, 0x01, 0x04, 0x7b])
        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .array(let array) = result[0] {
            XCTAssertEqual(array.count, 1)
            if case .int(let value) = array[0] {
                XCTAssertEqual(value, 123)
            } else {
                XCTFail("Expected int in array")
            }
        } else {
            XCTFail("Expected array value")
        }
    }

    // MARK: - ByteArray Decoding

    func testDecodeByteArray() throws {
        let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let length = (bytes.count << 1) | 0x01
        var data = Data([0x0c, UInt8(length)])
        data.append(bytes)

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .byteArray(let value) = result[0] {
            XCTAssertEqual(value, bytes)
        } else {
            XCTFail("Expected byte array value")
        }
    }

    // MARK: - Vector Decoding

    func testDecodeVectorInt() throws {
        let count = 3
        let length = (count << 1) | 0x01
        var data = Data([0x0d, UInt8(length), 0x00])

        let values: [Int32] = [1, 2, 3]
        for value in values {
            data.append(Data(value.bigEndian.data))
        }

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .vectorInt(let vector) = result[0] {
            XCTAssertEqual(vector, values)
        } else {
            XCTFail("Expected vector int value")
        }
    }

    func testDecodeVectorUInt() throws {
        let count = 3
        let length = (count << 1) | 0x01
        var data = Data([0x0e, UInt8(length), 0x00])

        let values: [UInt32] = [10, 20, 30]
        for value in values {
            data.append(Data(value.bigEndian.data))
        }

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .vectorUInt(let vector) = result[0] {
            XCTAssertEqual(vector, values)
        } else {
            XCTFail("Expected vector uint value")
        }
    }

    func testDecodeVectorDouble() throws {
        let count = 3
        let length = (count << 1) | 0x01
        var data = Data([0x0f, UInt8(length), 0x00])

        let values: [Double] = [1.1, 2.2, 3.3]
        for value in values {
            data.append(Data(value.bitPattern.bigEndian.data))
        }

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 1)
        if case .vectorDouble(let vector) = result[0] {
            XCTAssertEqual(vector.count, values.count)
            for (i, value) in values.enumerated() {
                XCTAssertEqual(vector[i], value, accuracy: 0.0001)
            }
        } else {
            XCTFail("Expected vector double value")
        }
    }

    // MARK: - Reference Table Tests

    func testReferenceTableStringStorage() throws {
        let refTable = AMF3ReferenceTable()
        refTable.append("test1")
        refTable.append("test2")

        XCTAssertEqual(refTable.string(index: 0), "test1")
        XCTAssertEqual(refTable.string(index: 1), "test2")
    }

    func testReferenceTableObjectStorage() throws {
        let refTable = AMF3ReferenceTable()
        let testData = Data([0x01, 0x02])
        refTable.append(testData)

        let retrieved: Data? = refTable.object(0)
        XCTAssertEqual(retrieved, testData)
    }

    func testReferenceTableReserveAndReplace() throws {
        let refTable = AMF3ReferenceTable()
        let idx = refTable.createReserved()

        let testDict: [String: AMFValue] = ["key": .string("value")]
        refTable.replace(testDict, idx: idx)

        let retrieved: [String: AMFValue]? = refTable.object(idx)
        XCTAssertNotNil(retrieved)
        if let dict = retrieved {
            if case .string(let value) = dict["key"] {
                XCTAssertEqual(value, "value")
            } else {
                XCTFail("Expected string value in dictionary")
            }
        }
    }

    // MARK: - Error Cases

    func testDecodeInvalidType() throws {
        let data = Data([0xFF])
        XCTAssertThrowsError(try decoder.decode(data)) { error in
            XCTAssertTrue(error is AMF3DecodeError)
        }
    }

    func testDecodeIncompleteData() throws {
        let data = Data([0x05, 0x01, 0x02])
        XCTAssertThrowsError(try decoder.decode(data)) { error in
            XCTAssertTrue(error is AMF3DecodeError)
        }
    }

    // MARK: - Multiple Values

    func testDecodeMultipleValues() throws {
        var data = Data([0x01])
        data.append(0x03)
        data.append(contentsOf: [0x04, 0x7b])

        let result = try decoder.decode(data)
        XCTAssertEqual(result.count, 3)

        if case .null = result[0] {
            // Success
        } else {
            XCTFail("Expected null")
        }

        if case .bool(let value) = result[1] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected bool true")
        }

        if case .int(let value) = result[2] {
            XCTAssertEqual(value, 123)
        } else {
            XCTFail("Expected int 123")
        }
    }
}
