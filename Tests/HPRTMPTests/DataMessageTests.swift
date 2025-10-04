//
//  DataMessageTests.swift
//
//
//  Created by Claude Code on 2025/10/04.
//

import XCTest
@testable import HPRTMP

final class DataMessageTests: XCTestCase {

  // MARK: - MetaMessage Tests

  func testMetaMessageAMF0Encoding() {
    let meta = MetaData(
      width: 1920,
      height: 1080,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30,
      videodatarate: 2500,
      audiodatarate: 128,
      audiosamplerate: 44100
    )

    let message = MetaMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      meta: meta
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)

    // First element should be "onMetaData"
    XCTAssertEqual(decoded?[0].stringValue, "onMetaData")

    // Second element should be the metadata object
    let metaObject = decoded?[1].objectValue
    XCTAssertNotNil(metaObject)
    XCTAssertEqual(metaObject?["width"]?.doubleValue, 1920.0)
    XCTAssertEqual(metaObject?["height"]?.doubleValue, 1080.0)
    XCTAssertEqual(metaObject?["videocodecid"]?.doubleValue, 7.0)
    XCTAssertEqual(metaObject?["audiocodecid"]?.doubleValue, 10.0)
    XCTAssertEqual(metaObject?["framerate"]?.doubleValue, 30.0)
    XCTAssertEqual(metaObject?["videodatarate"]?.doubleValue, 2500.0)
    XCTAssertEqual(metaObject?["audiodatarate"]?.doubleValue, 128.0)
    XCTAssertEqual(metaObject?["audiosamplerate"]?.doubleValue, 44100.0)
  }

  func testMetaMessageAMF3Encoding() {
    let meta = MetaData(
      width: 1280,
      height: 720,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 25,
      videodatarate: 1500,
      audiodatarate: nil,
      audiosamplerate: nil
    )

    let message = MetaMessage(
      encodeType: .amf3,
      msgStreamId: 1,
      meta: meta
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)

    // First element should be "onMetaData"
    XCTAssertEqual(decoded?[0].stringValue, "onMetaData")

    // Second element should be the metadata object
    let metaObject = decoded?[1].objectValue
    XCTAssertNotNil(metaObject)
    XCTAssertEqual(metaObject?["width"]?.doubleValue, 1280.0)
    XCTAssertEqual(metaObject?["height"]?.doubleValue, 720.0)
    XCTAssertEqual(metaObject?["videocodecid"]?.doubleValue, 7.0)
    XCTAssertEqual(metaObject?["framerate"]?.doubleValue, 25.0)
    XCTAssertEqual(metaObject?["videodatarate"]?.doubleValue, 1500.0)
    // Optional fields should not be present
    XCTAssertNil(metaObject?["audiodatarate"])
    XCTAssertNil(metaObject?["audiosamplerate"])
  }

  func testMetaMessageWithOptionalFields() {
    let meta = MetaData(
      width: 640,
      height: 480,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 15,
      videodatarate: 500,
      audiodatarate: 64,
      audiosamplerate: nil
    )

    let message = MetaMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      meta: meta
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    let metaObject = decoded?[1].objectValue
    XCTAssertNotNil(metaObject?["videodatarate"])
    XCTAssertEqual(metaObject?["videodatarate"]?.doubleValue, 500.0)
    XCTAssertNotNil(metaObject?["audiodatarate"])
    XCTAssertEqual(metaObject?["audiodatarate"]?.doubleValue, 64.0)
    XCTAssertNil(metaObject?["audiosamplerate"])
  }

  func testMetaMessageRoundTrip() async {
    let meta = MetaData(
      width: 1920,
      height: 1080,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30,
      videodatarate: 2500,
      audiodatarate: 128,
      audiosamplerate: 44100
    )

    let originalMessage = MetaMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      meta: meta
    )

    let payload = originalMessage.payload

    // Decode and verify structure
    let decoded = payload.decodeAMF0()
    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "onMetaData")

    let metaObject = decoded?[1].objectValue
    XCTAssertEqual(metaObject?["width"]?.doubleValue, 1920.0)
    XCTAssertEqual(metaObject?["height"]?.doubleValue, 1080.0)
  }

  // MARK: - SharedObjectMessage Tests

  func testSharedObjectMessageAMF0Encoding() {
    let sharedObject: [String: AMFValue] = [
      "name": .string("test"),
      "value": .double(123.45),
      "enabled": .bool(true)
    ]

    let message = SharedObjectMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      sharedObjectName: "myObject",
      sharedObject: sharedObject
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 3)

    // First element should be "onSharedObject"
    XCTAssertEqual(decoded?[0].stringValue, "onSharedObject")

    // Second element should be the object name
    XCTAssertEqual(decoded?[1].stringValue, "myObject")

    // Third element should be the shared object
    let decodedObject = decoded?[2].objectValue
    XCTAssertNotNil(decodedObject)
    XCTAssertEqual(decodedObject?["name"]?.stringValue, "test")
    XCTAssertEqual(decodedObject?["value"]?.doubleValue, 123.45)
    XCTAssertEqual(decodedObject?["enabled"]?.boolValue, true)
  }

  func testSharedObjectMessageAMF3Encoding() {
    let sharedObject: [String: AMFValue] = [
      "count": .double(42.0),
      "active": .bool(false)
    ]

    let message = SharedObjectMessage(
      encodeType: .amf3,
      msgStreamId: 1,
      sharedObjectName: "counter",
      sharedObject: sharedObject
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 3)

    XCTAssertEqual(decoded?[0].stringValue, "onSharedObject")
    XCTAssertEqual(decoded?[1].stringValue, "counter")

    let decodedObject = decoded?[2].objectValue
    XCTAssertEqual(decodedObject?["count"]?.doubleValue, 42.0)
    XCTAssertEqual(decodedObject?["active"]?.boolValue, false)
  }

  func testSharedObjectMessageWithoutName() {
    let sharedObject: [String: AMFValue] = [
      "data": .string("test")
    ]

    let message = SharedObjectMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      sharedObjectName: nil,
      sharedObject: sharedObject
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    // Should have 2 elements: command name and object (no name)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "onSharedObject")

    let decodedObject = decoded?[1].objectValue
    XCTAssertEqual(decodedObject?["data"]?.stringValue, "test")
  }

  func testSharedObjectMessageWithComplexValue() {
    let nestedObject: [String: AMFValue] = [
      "nested": .string("value")
    ]

    let sharedObject: [String: AMFValue] = [
      "simple": .string("text"),
      "number": .double(99.9),
      "array": .array([.string("a"), .string("b"), .double(1.0)]),
      "object": .object(nestedObject)
    ]

    let message = SharedObjectMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      sharedObjectName: "complex",
      sharedObject: sharedObject
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    let decodedObject = decoded?[2].objectValue

    XCTAssertEqual(decodedObject?["simple"]?.stringValue, "text")
    XCTAssertEqual(decodedObject?["number"]?.doubleValue, 99.9)

    let array = decodedObject?["array"]?.arrayValue
    XCTAssertEqual(array?.count, 3)
    XCTAssertEqual(array?[0].stringValue, "a")

    let nested = decodedObject?["object"]?.objectValue
    XCTAssertEqual(nested?["nested"]?.stringValue, "value")
  }

  func testSharedObjectMessageRoundTrip() async {
    let sharedObject: [String: AMFValue] = [
      "key": .string("value"),
      "number": .double(456.0)
    ]

    let originalMessage = SharedObjectMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      sharedObjectName: "testObject",
      sharedObject: sharedObject
    )

    let payload = originalMessage.payload

    // Decode using MessageDecoder
    let decoder = MessageDecoder()
    let decodedMessage = await decoder.createMessage(
      chunkStreamId: RTMPChunkStreamId.command.rawValue,
      msgStreamId: 1,
      messageType: .share(type: .amf0),
      timestamp: 0,
      chunkPayload: payload
    )

    XCTAssertNotNil(decodedMessage)
    XCTAssertTrue(decodedMessage is SharedObjectMessage)

    let sharedMessage = decodedMessage as? SharedObjectMessage
    XCTAssertEqual(sharedMessage?.sharedObjectName, "testObject")
    XCTAssertEqual(sharedMessage?.sharedObject?["key"]?.stringValue, "value")
    XCTAssertEqual(sharedMessage?.sharedObject?["number"]?.doubleValue, 456.0)
  }
}
