//
//  AMF3EncoderTests.swift
//
//
//  Created by AMF3 Test Suite
//

import XCTest
@testable import HPRTMP

final class AMF3EncoderTests: XCTestCase {

    var encoder: AMF3Encoder!

    override func setUpWithError() throws {
        encoder = AMF3Encoder()
    }

    override func tearDownWithError() throws {
        encoder = nil
    }

    // MARK: - Basic Types Encoding

    func testEncodeBool() throws {
        let trueData = try encoder.encode(true)
        XCTAssertEqual(trueData, Data([0x03]))

        let falseData = try encoder.encode(false)
        XCTAssertEqual(falseData, Data([0x02]))
    }

    func testEncodeSmallInt() throws {
        let data = try encoder.encode(123)
        XCTAssertEqual(data, Data([0x04, 0x7b]))
    }

    func testEncodeMediumInt() throws {
        let data = try encoder.encode(128)
        XCTAssertEqual(data, Data([0x04, 0x81, 0x00]))
    }

    func testEncodeLargeInt() throws {
        let value = 0x3fff
        let data = try encoder.encode(value)
        XCTAssertTrue(data.count > 0)
        XCTAssertEqual(data[0], 0x04)
    }

    func testEncodeDouble() throws {
        let doubleValue: Double = 3.14159265359
        let data = try encoder.encode(doubleValue)

        XCTAssertEqual(data[0], 0x05)
        XCTAssertEqual(data.count, 9)

        // Verify can be decoded correctly
        let decodedData = data.dropFirst()
        let reversed = Data(decodedData.reversed())
        let decoded = reversed.withUnsafeBytes { $0.load(as: Double.self) }
        XCTAssertEqual(decoded, doubleValue, accuracy: 0.0000001)
    }

    func testEncodeString() throws {
        let testString = "hello"
        let data = try encoder.encode(testString)

        XCTAssertEqual(data[0], 0x06)

        let expectedLength = (testString.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))

        let stringData = data.dropFirst(2)
        XCTAssertEqual(String(data: stringData, encoding: .utf8), testString)
    }

    func testEncodeEmptyString() throws {
        let emptyString = ""
        let data = try encoder.encode(emptyString)

        XCTAssertEqual(data[0], 0x06)
        XCTAssertEqual(data[1], 0x01)
        XCTAssertEqual(data.count, 2)
    }

    func testEncodeLongString() throws {
        let longString = String(repeating: "a", count: 1000)
        let data = try encoder.encode(longString)

        XCTAssertEqual(data[0], 0x06)
        XCTAssertTrue(data.count > 1000)
    }

    func testEncodeDate() throws {
        let date = Date()
        let data = try encoder.encode(date)

        XCTAssertEqual(data[0], 0x08)
        XCTAssertEqual(data[1], 0x01)
        XCTAssertEqual(data.count, 10)
    }

    // MARK: - Array Encoding

    func testEncodeArray() throws {
        let array: [Any] = [123, "test", true]
        let data = try encoder.encode(array)

        XCTAssertEqual(data[0], 0x09)

        let expectedLength = (array.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))
    }

    func testEncodeEmptyArray() throws {
        let array: [Any] = []
        let data = try encoder.encode(array)

        XCTAssertEqual(data[0], 0x09)
        XCTAssertEqual(data[1], 0x01)
    }

    func testEncodeIntArray() throws {
        let array: [Int] = [1, 2, 3, 4, 5]
        let data = try encoder.encode(array)

        XCTAssertEqual(data[0], 0x09) // array marker
        let expectedLength = (array.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))
    }

    // MARK: - Dictionary Encoding

    func testEncodeDictionary() throws {
        // Note: Dictionary cannot be encoded via encoder.encode(), only via amf3Value extension
        // This is a design limitation
        let dict: [String: Any?] = ["key1": "value1", "key2": 123]
        let data = dict.amf3Value

        XCTAssertEqual(data[0], 0x0a)
    }

    func testEncodeEmptyDictionary() throws {
        // Note: Dictionary cannot be encoded via encoder.encode(), only via amf3Value extension
        let dict: [String: Any?] = [:]
        let data = dict.amf3Value

        XCTAssertEqual(data[0], 0x0a)
    }

    // MARK: - ByteArray Encoding

    func testEncodeByteArray() throws {
        let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let data = try encoder.encode(bytes)

        XCTAssertEqual(data[0], 0x0c)

        let expectedLength = (bytes.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))

        let encodedBytes = data.dropFirst(2)
        XCTAssertEqual(encodedBytes, bytes)
    }

    func testEncodeEmptyByteArray() throws {
        let bytes = Data()
        let data = try encoder.encode(bytes)

        XCTAssertEqual(data[0], 0x0c)
        XCTAssertEqual(data[1], 0x01)
    }

    // MARK: - Vector Encoding

    func testEncodeVectorInt() throws {
        // Note: Vector cannot be encoded via encoder.encode()
        // Array implements both AMF3Encodable and AMF3VectorEncodable
        // encoder.encode() prioritizes AMF3Encodable, encoding as regular array
        // To encode as vector, must explicitly call amf3VectorValue
        let vector: [Int32] = [1, 2, 3]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0d)

        let expectedLength = (vector.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))
        XCTAssertEqual(data[2], 0x00)
    }

    func testEncodeVectorUInt() throws {
        let vector: [UInt32] = [10, 20, 30]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0e)

        let expectedLength = (vector.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))
        XCTAssertEqual(data[2], 0x00)
    }

    func testEncodeVectorDouble() throws {
        let vector: [Double] = [1.1, 2.2, 3.3]
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0f)

        let expectedLength = (vector.count << 1) | 0x01
        XCTAssertEqual(data[1], UInt8(expectedLength))
        XCTAssertEqual(data[2], 0x00)
    }

    func testEncodeVectorIntAsArray() throws {
        // Test: [Int32] via encoder.encode() is encoded as array, not vector
        // This exposes current implementation limitation
        let vector: [Int32] = [1, 2, 3]
        let data = try encoder.encode(vector)

        XCTAssertEqual(data[0], 0x09)
    }

    func testEncodeEmptyVectorInt() throws {
        let vector: [Int32] = []
        let data = vector.amf3VectorValue

        XCTAssertEqual(data[0], 0x0d)
        XCTAssertEqual(data[1], 0x01)
    }

    // MARK: - Error Cases

    func testEncodeUnsupportedType() throws {
        struct UnsupportedType {}
        let unsupported = UnsupportedType()

        XCTAssertThrowsError(try encoder.encode(unsupported)) { error in
            if let encoderError = error as? AMF3Encoder.AMF3EncoderError {
                XCTAssertEqual(encoderError, .unsupportedType)
            } else {
                XCTFail("Expected AMF3EncoderError.unsupportedType")
            }
        }
    }

    // MARK: - Round Trip Tests (Encode + Decode)

    func testRoundTripInt() throws {
        let original = 12345
        let encoded = try encoder.encode(original)

        let decoded = encoded.decodeAMF3()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 1)

        if let decoded = decoded, case .int(let value) = decoded[0] {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed to decode int")
        }
    }

    func testRoundTripString() throws {
        let original = "Hello, AMF3!"
        let encoded = try encoder.encode(original)

        let decoded = encoded.decodeAMF3()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .string(let value) = decoded[0] {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed to decode string")
        }
    }

    func testRoundTripBool() throws {
        let originalTrue = true
        let encodedTrue = try encoder.encode(originalTrue)
        let decodedTrue = encodedTrue.decodeAMF3()

        if let decoded = decodedTrue, case .bool(let value) = decoded[0] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Failed to decode bool true")
        }

        let originalFalse = false
        let encodedFalse = try encoder.encode(originalFalse)
        let decodedFalse = encodedFalse.decodeAMF3()

        if let decoded = decodedFalse, case .bool(let value) = decoded[0] {
            XCTAssertFalse(value)
        } else {
            XCTFail("Failed to decode bool false")
        }
    }

    func testRoundTripDouble() throws {
        let original: Double = 3.14159265359
        let encoded = try encoder.encode(original)

        let decoded = encoded.decodeAMF3()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .double(let value) = decoded[0] {
            XCTAssertEqual(value, original, accuracy: 0.0000001)
        } else {
            XCTFail("Failed to decode double")
        }
    }

    func testRoundTripByteArray() throws {
        let original = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let encoded = try encoder.encode(original)

        let decoded = encoded.decodeAMF3()
        XCTAssertNotNil(decoded)

        if let decoded = decoded, case .byteArray(let value) = decoded[0] {
            XCTAssertEqual(value, original)
        } else {
            XCTFail("Failed to decode byte array")
        }
    }
}
