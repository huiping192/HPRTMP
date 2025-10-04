//
//  CommandMessageTests.swift
//
//
//  Created by Claude Code on 2025/10/04.
//

import XCTest
@testable import HPRTMP

final class CommandMessageTests: XCTestCase {

  // MARK: - CommandMessage Base Tests

  func testCommandMessageAMF0Encoding() {
    let commandObject: [String: AMFValue] = [
      "app": .string("test"),
      "version": .double(1.0)
    ]
    let message = CommandMessage(
      encodeType: .amf0,
      commandName: "connect",
      transactionId: 1,
      commandObject: commandObject,
      info: .string("info"),
      msgStreamId: 0,
      timestamp: 0
    )

    let payload = message.payload

    // Decode and verify
    let decoder = AMF0Decoder()
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 4)
    XCTAssertEqual(decoded?[0].stringValue, "connect")
    XCTAssertEqual(decoded?[1].doubleValue, 1.0)
    XCTAssertEqual(decoded?[2].objectValue?["app"]?.stringValue, "test")
    XCTAssertEqual(decoded?[3].stringValue, "info")
  }

  func testCommandMessageAMF3Encoding() {
    let commandObject: [String: AMFValue] = [
      "app": .string("test"),
      "version": .double(1.0)
    ]
    let message = CommandMessage(
      encodeType: .amf3,
      commandName: "connect",
      transactionId: 1,
      commandObject: commandObject,
      info: .string("info"),
      msgStreamId: 0,
      timestamp: 0
    )

    let payload = message.payload

    // Decode and verify
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 4)
    XCTAssertEqual(decoded?[0].stringValue, "connect")
    XCTAssertEqual(decoded?[1].doubleValue, 1.0)
    XCTAssertEqual(decoded?[2].objectValue?["app"]?.stringValue, "test")
    XCTAssertEqual(decoded?[3].stringValue, "info")
  }

  // MARK: - ConnectMessage Tests

  func testConnectMessageAMF0Encoding() {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/app",
      appName: "testApp",
      flashVer: "FMLE/3.0",
      swfURL: nil,
      fpad: false,
      audio: RTMPAudioCodecsType.all,
      video: RTMPVideoCodecsType.all,
      pageURL: nil
    )

    let payload = message.payload

    // Decode and verify
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertGreaterThanOrEqual(decoded?.count ?? 0, 3)
    XCTAssertEqual(decoded?[0].stringValue, "connect")
    XCTAssertEqual(decoded?[1].doubleValue, 1.0) // transactionId

    let commandObject = decoded?[2].objectValue
    XCTAssertEqual(commandObject?["app"]?.stringValue, "testApp")
    XCTAssertEqual(commandObject?["tcUrl"]?.stringValue, "rtmp://localhost/app")
    XCTAssertEqual(commandObject?["flashver"]?.stringValue, "FMLE/3.0")
  }

  func testConnectMessageAMF3Encoding() {
    let message = ConnectMessage(
      encodeType: .amf3,
      tcUrl: "rtmp://localhost/app",
      appName: "testApp",
      flashVer: "FMLE/3.0",
      swfURL: nil,
      fpad: false,
      audio: RTMPAudioCodecsType.all,
      video: RTMPVideoCodecsType.all,
      pageURL: nil
    )

    let payload = message.payload

    // Decode and verify
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertGreaterThanOrEqual(decoded?.count ?? 0, 3)
    XCTAssertEqual(decoded?[0].stringValue, "connect")
    XCTAssertEqual(decoded?[1].doubleValue, 1.0)

    let commandObject = decoded?[2].objectValue
    XCTAssertEqual(commandObject?["app"]?.stringValue, "testApp")
  }

  // MARK: - CreateStreamMessage Tests

  func testCreateStreamMessageAMF0Encoding() {
    let message = CreateStreamMessage(
      encodeType: .amf0,
      transactionId: 2,
      commonObject: nil
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 3)
    XCTAssertEqual(decoded?[0].stringValue, "createStream")
    XCTAssertEqual(decoded?[1].doubleValue, 2.0)
    XCTAssertEqual(decoded?[2].stringValue, "null") // null value
  }

  func testCreateStreamMessageAMF3Encoding() {
    let message = CreateStreamMessage(
      encodeType: .amf3,
      transactionId: 2,
      commonObject: nil
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 3)
    XCTAssertEqual(decoded?[0].stringValue, "createStream")
    XCTAssertEqual(decoded?[1].doubleValue, 2.0)
    // AMF3 null check
    XCTAssertTrue(decoded?[2] == .null || decoded?[2] == .undefined)
  }

  // MARK: - CloseStreamMessage Tests

  func testCloseStreamMessageAMF0Encoding() {
    let message = CloseStreamMessage(
      encodeType: .amf0,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "closeStream")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
  }

  func testCloseStreamMessageAMF3Encoding() {
    let message = CloseStreamMessage(
      encodeType: .amf3,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "closeStream")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
  }

  // MARK: - DeleteStreamMessage Tests

  func testDeleteStreamMessageAMF0Encoding() {
    let message = DeleteStreamMessage(
      encodeType: .amf0,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "deleteStream")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
  }

  func testDeleteStreamMessageAMF3Encoding() {
    let message = DeleteStreamMessage(
      encodeType: .amf3,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 2)
    XCTAssertEqual(decoded?[0].stringValue, "deleteStream")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
  }

  // MARK: - PublishMessage Tests

  func testPublishMessageAMF0Encoding() {
    let message = PublishMessage(
      encodeType: .amf0,
      streamName: "testStream",
      type: .live,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 5)
    XCTAssertEqual(decoded?[0].stringValue, "publish")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertEqual(decoded?[2].stringValue, "null")
    XCTAssertEqual(decoded?[3].stringValue, "testStream")
    XCTAssertEqual(decoded?[4].stringValue, "live")
  }

  func testPublishMessageAMF3Encoding() {
    let message = PublishMessage(
      encodeType: .amf3,
      streamName: "testStream",
      type: .record,
      msgStreamId: 1
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 5)
    XCTAssertEqual(decoded?[0].stringValue, "publish")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertTrue(decoded?[2] == .null || decoded?[2] == .undefined)
    XCTAssertEqual(decoded?[3].stringValue, "testStream")
    XCTAssertEqual(decoded?[4].stringValue, "record")
  }

  // MARK: - SeekMessage Tests

  func testSeekMessageAMF0Encoding() {
    let message = SeekMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      millSecond: 5000.0
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 4)
    XCTAssertEqual(decoded?[0].stringValue, "seek")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertEqual(decoded?[2].stringValue, "null")
    XCTAssertEqual(decoded?[3].doubleValue, 5000.0)
  }

  func testSeekMessageAMF3Encoding() {
    let message = SeekMessage(
      encodeType: .amf3,
      msgStreamId: 1,
      millSecond: 5000.0
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 4)
    XCTAssertEqual(decoded?[0].stringValue, "seek")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertTrue(decoded?[2] == .null || decoded?[2] == .undefined)
    XCTAssertEqual(decoded?[3].doubleValue, 5000.0)
  }

  // MARK: - PauseMessage Tests

  func testPauseMessageAMF0Encoding() {
    let message = PauseMessage(
      encodeType: .amf0,
      msgStreamId: 1,
      isPause: true,
      millSecond: 3000.0
    )

    let payload = message.payload
    let decoded = payload.decodeAMF0()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 5)
    XCTAssertEqual(decoded?[0].stringValue, "pause")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertEqual(decoded?[2].stringValue, "null")
    XCTAssertEqual(decoded?[3].boolValue, true)
    XCTAssertEqual(decoded?[4].doubleValue, 3000.0)
  }

  func testPauseMessageAMF3Encoding() {
    let message = PauseMessage(
      encodeType: .amf3,
      msgStreamId: 1,
      isPause: false,
      millSecond: 3000.0
    )

    let payload = message.payload
    let decoded = payload.decodeAMF3()

    XCTAssertNotNil(decoded)
    XCTAssertEqual(decoded?.count, 5)
    XCTAssertEqual(decoded?[0].stringValue, "pause")
    XCTAssertEqual(decoded?[1].doubleValue, 0.0)
    XCTAssertTrue(decoded?[2] == .null || decoded?[2] == .undefined)
    XCTAssertEqual(decoded?[3].boolValue, false)
    XCTAssertEqual(decoded?[4].doubleValue, 3000.0)
  }

  // MARK: - Round-trip Tests

  func testCommandMessageRoundTrip() async {
    // Create a command message
    let commandObject: [String: AMFValue] = [
      "app": .string("testApp"),
      "version": .double(1.0),
      "enabled": .bool(true)
    ]

    let originalMessage = CommandMessage(
      encodeType: .amf0,
      commandName: "connect",
      transactionId: 1,
      commandObject: commandObject,
      info: .double(5.0),
      msgStreamId: 0,
      timestamp: 100
    )

    // Encode to payload
    let payload = originalMessage.payload

    // Decode using MessageDecoder
    let decoder = MessageDecoder()
    let decodedMessage = await decoder.createMessage(
      chunkStreamId: RTMPChunkStreamId.command.rawValue,
      msgStreamId: 0,
      messageType: .command(type: .amf0),
      timestamp: 100,
      chunkPayload: payload
    )

    XCTAssertNotNil(decodedMessage)
    XCTAssertTrue(decodedMessage is CommandMessage)

    let commandMessage = decodedMessage as? CommandMessage
    XCTAssertEqual(commandMessage?.commandName, "connect")
    XCTAssertEqual(commandMessage?.transactionId, 1)
    XCTAssertEqual(commandMessage?.commandObject?["app"]?.stringValue, "testApp")
    XCTAssertEqual(commandMessage?.info?.doubleValue, 5.0)
  }
}
