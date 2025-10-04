//
//  AMFValueTests.swift
//
//
//  Created by Claude Code on 2025/10/04.
//

import XCTest
@testable import HPRTMP

final class AMFValueTests: XCTestCase {

  // MARK: - AMF0 Encoding Tests

  func testAMF0DoubleEncoding() {
    let value = AMFValue.double(123.45)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.doubleValue, 123.45)
  }

  func testAMF0BoolEncoding() {
    let trueValue = AMFValue.bool(true)
    let falseValue = AMFValue.bool(false)

    let trueEncoded = trueValue.amf0Value
    let falseEncoded = falseValue.amf0Value

    let trueDecoded = trueEncoded.decodeAMF0()
    let falseDecoded = falseEncoded.decodeAMF0()

    XCTAssertEqual(trueDecoded?.first?.boolValue, true)
    XCTAssertEqual(falseDecoded?.first?.boolValue, false)
  }

  func testAMF0StringEncoding() {
    let value = AMFValue.string("Hello, RTMP!")
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.stringValue, "Hello, RTMP!")
  }

  func testAMF0NullEncoding() {
    let value = AMFValue.null
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.stringValue, "null")
  }

  func testAMF0ObjectEncoding() {
    let object: [String: AMFValue] = [
      "name": .string("test"),
      "value": .double(42.0),
      "enabled": .bool(true)
    ]
    let value = AMFValue.object(object)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    let decodedObject = decoded?.first?.objectValue

    XCTAssertEqual(decodedObject?["name"]?.stringValue, "test")
    XCTAssertEqual(decodedObject?["value"]?.doubleValue, 42.0)
    XCTAssertEqual(decodedObject?["enabled"]?.boolValue, true)
  }

  func testAMF0ArrayEncoding() {
    let array: [AMFValue] = [
      .string("first"),
      .double(2.0),
      .bool(true)
    ]
    let value = AMFValue.array(array)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    let decodedArray = decoded?.first?.arrayValue

    XCTAssertEqual(decodedArray?.count, 3)
    XCTAssertEqual(decodedArray?[0].stringValue, "first")
    XCTAssertEqual(decodedArray?[1].doubleValue, 2.0)
    XCTAssertEqual(decodedArray?[2].boolValue, true)
  }

  func testAMF0DateEncoding() {
    let date = Date(timeIntervalSince1970: 1234567890)
    let value = AMFValue.date(date)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.dateValue, date)
  }

  func testAMF0NestedObjectEncoding() {
    let nestedObject: [String: AMFValue] = [
      "nested": .string("value")
    ]
    let object: [String: AMFValue] = [
      "simple": .string("text"),
      "object": .object(nestedObject),
      "array": .array([.double(1.0), .double(2.0)])
    ]
    let value = AMFValue.object(object)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    let decodedObject = decoded?.first?.objectValue

    XCTAssertEqual(decodedObject?["simple"]?.stringValue, "text")

    let nested = decodedObject?["object"]?.objectValue
    XCTAssertEqual(nested?["nested"]?.stringValue, "value")

    let array = decodedObject?["array"]?.arrayValue
    XCTAssertEqual(array?.count, 2)
  }

  // MARK: - AMF3 Encoding Tests

  func testAMF3DoubleEncoding() {
    let value = AMFValue.double(678.90)
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    XCTAssertEqual(decoded?.first?.doubleValue, 678.90)
  }

  func testAMF3IntEncoding() {
    let value = AMFValue.int(42)
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    XCTAssertEqual(decoded?.first?.intValue, 42)
  }

  func testAMF3BoolEncoding() {
    let trueValue = AMFValue.bool(true)
    let falseValue = AMFValue.bool(false)

    let trueEncoded = trueValue.amf3Value
    let falseEncoded = falseValue.amf3Value

    let trueDecoded = trueEncoded.decodeAMF3()
    let falseDecoded = falseEncoded.decodeAMF3()

    XCTAssertEqual(trueDecoded?.first?.boolValue, true)
    XCTAssertEqual(falseDecoded?.first?.boolValue, false)
  }

  func testAMF3StringEncoding() {
    let value = AMFValue.string("AMF3 String")
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    XCTAssertEqual(decoded?.first?.stringValue, "AMF3 String")
  }

  func testAMF3NullEncoding() {
    let value = AMFValue.null
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    XCTAssertTrue(decoded?.first == .null)
  }

  func testAMF3UndefinedEncoding() {
    let value = AMFValue.undefined
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    XCTAssertTrue(decoded?.first == .undefined)
  }

  func testAMF3ObjectEncoding() {
    let object: [String: AMFValue] = [
      "key": .string("value"),
      "number": .int(123)
    ]
    let value = AMFValue.object(object)
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    let decodedObject = decoded?.first?.objectValue

    XCTAssertEqual(decodedObject?["key"]?.stringValue, "value")
    XCTAssertEqual(decodedObject?["number"]?.intValue, 123)
  }

  func testAMF3ArrayEncoding() {
    let array: [AMFValue] = [
      .int(1),
      .int(2),
      .string("three")
    ]
    let value = AMFValue.array(array)
    let encoded = value.amf3Value

    let decoded = encoded.decodeAMF3()
    let decodedArray = decoded?.first?.arrayValue

    XCTAssertEqual(decodedArray?.count, 3)
    XCTAssertEqual(decodedArray?[0].intValue, 1)
    XCTAssertEqual(decodedArray?[1].intValue, 2)
    XCTAssertEqual(decodedArray?[2].stringValue, "three")
  }

  // MARK: - Type Conversion Tests

  func testAMF0IntToDoubleConversion() {
    // AMF0 doesn't have int type, should convert to double
    let value = AMFValue.int(100)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.doubleValue, 100.0)
  }

  func testAMF0UndefinedToNullConversion() {
    // AMF0 doesn't have undefined, should use null
    let value = AMFValue.undefined
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    XCTAssertEqual(decoded?.first?.stringValue, "null")
  }

  func testAMF0ByteArrayToStringConversion() {
    // AMF0 doesn't have byteArray, should encode as base64 string
    let data = Data([0x01, 0x02, 0x03, 0x04])
    let value = AMFValue.byteArray(data)
    let encoded = value.amf0Value

    let decoded = encoded.decodeAMF0()
    // Should be base64 encoded string
    XCTAssertNotNil(decoded?.first?.stringValue)
  }

  // MARK: - Complex Encoding Tests

  func testComplexNestedStructure() {
    let complex: [String: AMFValue] = [
      "users": .array([
        .object(["name": .string("Alice"), "age": .double(30.0)]),
        .object(["name": .string("Bob"), "age": .double(25.0)])
      ]),
      "metadata": .object([
        "created": .date(Date(timeIntervalSince1970: 1000000)),
        "active": .bool(true)
      ])
    ]

    let value = AMFValue.object(complex)

    // Test AMF0
    let amf0Encoded = value.amf0Value
    let amf0Decoded = amf0Encoded.decodeAMF0()
    let amf0Object = amf0Decoded?.first?.objectValue

    let users = amf0Object?["users"]?.arrayValue
    XCTAssertEqual(users?.count, 2)
    XCTAssertEqual(users?[0].objectValue?["name"]?.stringValue, "Alice")

    // Test AMF3
    let amf3Encoded = value.amf3Value
    let amf3Decoded = amf3Encoded.decodeAMF3()
    let amf3Object = amf3Decoded?.first?.objectValue

    let users3 = amf3Object?["users"]?.arrayValue
    XCTAssertEqual(users3?.count, 2)
    XCTAssertEqual(users3?[1].objectValue?["name"]?.stringValue, "Bob")
  }

  func testEmptyCollections() {
    // Empty object
    let emptyObject = AMFValue.object([:])
    let emptyObjectEncoded = emptyObject.amf0Value
    let emptyObjectDecoded = emptyObjectEncoded.decodeAMF0()
    XCTAssertNotNil(emptyObjectDecoded?.first?.objectValue)

    // Empty array
    let emptyArray = AMFValue.array([])
    let emptyArrayEncoded = emptyArray.amf0Value
    let emptyArrayDecoded = emptyArrayEncoded.decodeAMF0()
    XCTAssertEqual(emptyArrayDecoded?.first?.arrayValue?.count, 0)
  }

  func testAllPrimitiveTypes() {
    let values: [AMFValue] = [
      .double(3.14),
      .bool(true),
      .string("test"),
      .null,
      .date(Date())
    ]

    for value in values {
      // Test AMF0 round-trip
      let amf0Encoded = value.amf0Value
      let amf0Decoded = amf0Encoded.decodeAMF0()
      XCTAssertNotNil(amf0Decoded?.first)

      // Test AMF3 round-trip
      let amf3Encoded = value.amf3Value
      let amf3Decoded = amf3Encoded.decodeAMF3()
      XCTAssertNotNil(amf3Decoded?.first)
    }
  }
}
