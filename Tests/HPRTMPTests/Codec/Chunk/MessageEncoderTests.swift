//
//  MessageEncoderTests.swift
//  
//
//  Created by 郭 輝平 on 2023/03/18.
//

import XCTest
@testable import HPRTMP

final class MessageEncoderTests: XCTestCase {
  
  func testSingleChunkFirst() async throws {
    let message = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1234)
    let encoder = MessageEncoder()

    // When
    let chunks = await encoder.encode(message: message, isFirstType0: true)

    // Then
    XCTAssertEqual(chunks.count, 1)
    let firstChunk = chunks[0]
    let header = firstChunk.chunkHeader
    XCTAssertTrue(header.messageHeader is MessageHeaderType0)
    let messageHeader = header.messageHeader as! MessageHeaderType0
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPChunkStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.messageStreamId, 10)
    XCTAssertEqual(messageHeader.timestamp, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, MessageType.audio)
    XCTAssertEqual(firstChunk.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
  }

  func testSingleChunkNotFirst() async throws {
    let message = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1234)
    let encoder = MessageEncoder()

    // When
    let chunks = await encoder.encode(message: message, isFirstType0: false)

    // Then
    XCTAssertEqual(chunks.count, 1)
    let firstChunk = chunks[0]
    let header = firstChunk.chunkHeader
    XCTAssertTrue(header.messageHeader is MessageHeaderType1)
    let messageHeader = header.messageHeader as! MessageHeaderType1
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPChunkStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.timestampDelta, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, MessageType.audio)
    XCTAssertEqual(firstChunk.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
  }

  func testChunk_multipleChunks() async throws {
    let message = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]), msgStreamId: 10, timestamp: 1234)
    let encoder = MessageEncoder()
    try await encoder.setChunkSize(chunkSize: 4)
    
    // When
    let chunks = await encoder.encode(message: message, isFirstType0: true)
    
    // Then
    XCTAssertEqual(chunks.count, 2)
    
    let chunk0 = chunks[0]
    let header0 = chunk0.chunkHeader
    XCTAssertTrue(header0.messageHeader is MessageHeaderType0)
    let messageHeader0 = header0.messageHeader as! MessageHeaderType0
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(messageHeader0.timestamp, 1234)
    XCTAssertEqual(messageHeader0.messageLength, 8)
    XCTAssertEqual(messageHeader0.type, MessageType.audio)
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(chunk0.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
    
    let chunk1 = chunks[1]
    let header1 = chunk1.chunkHeader
    XCTAssertTrue(header1.messageHeader is MessageHeaderType3)
    let messageHeader1 = header1.messageHeader as! MessageHeaderType3
    XCTAssertEqual(messageHeader1.encode().count, 0)
    XCTAssertEqual(chunk1.chunkData, Data([0x05, 0x06, 0x07, 0x08]))
  }

  func testSetChunkSize_validBoundaries() async throws {
    let encoder = MessageEncoder()

    // Test minimum valid size
    try await encoder.setChunkSize(chunkSize: MessageEncoder.minChunkSize)

    // Test maximum valid size
    try await encoder.setChunkSize(chunkSize: MessageEncoder.maxChunkSize)

    // Test typical size
    try await encoder.setChunkSize(chunkSize: 128)
  }

  func testSetChunkSize_invalidTooSmall() async throws {
    let encoder = MessageEncoder()

    do {
      try await encoder.setChunkSize(chunkSize: 0)
      XCTFail("Should throw error for chunk size 0")
    } catch let error as RTMPError {
      if case .invalidChunkSize(let size, let min, let max) = error {
        XCTAssertEqual(size, 0)
        XCTAssertEqual(min, MessageEncoder.minChunkSize)
        XCTAssertEqual(max, MessageEncoder.maxChunkSize)
      } else {
        XCTFail("Wrong error type")
      }
    }
  }

  func testSetChunkSize_invalidTooLarge() async throws {
    let encoder = MessageEncoder()
    let invalidSize: UInt32 = MessageEncoder.maxChunkSize + 1

    do {
      try await encoder.setChunkSize(chunkSize: invalidSize)
      XCTFail("Should throw error for chunk size > maxChunkSize")
    } catch let error as RTMPError {
      if case .invalidChunkSize(let size, let min, let max) = error {
        XCTAssertEqual(size, invalidSize)
        XCTAssertEqual(min, MessageEncoder.minChunkSize)
        XCTAssertEqual(max, MessageEncoder.maxChunkSize)
      } else {
        XCTFail("Wrong error type")
      }
    }
  }

  func testType2HeaderOptimization() async throws {
    let encoder = MessageEncoder()

    // First message: uses Type1 (no previous state)
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: false)
    XCTAssertEqual(chunks1.count, 1)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType1)

    // Second message: same length/type/streamId -> should use Type2
    let message2 = AudioMessage(data: Data([0x05, 0x06, 0x07, 0x08]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertEqual(chunks2.count, 1)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType2)

    let header2 = chunks2[0].chunkHeader.messageHeader as! MessageHeaderType2
    XCTAssertEqual(header2.timestampDelta, 1033)
  }

  func testType1WhenMessageLengthChanges() async throws {
    let encoder = MessageEncoder()

    // First message
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: false)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType1)

    // Second message: different length -> should use Type1
    let message2 = AudioMessage(data: Data([0x01, 0x02, 0x03]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType1)
  }

  func testType1WhenMessageTypeChanges() async throws {
    let encoder = MessageEncoder()

    // First message: Audio
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: false)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType1)

    // Second message: Video with same length -> should use Type1
    let message2 = VideoMessage(data: Data([0x05, 0x06, 0x07, 0x08]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType1)
  }

  func testType1WhenStreamIdChanges() async throws {
    let encoder = MessageEncoder()

    // First message
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: false)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType1)

    // Second message: different streamId -> should use Type1
    let message2 = AudioMessage(data: Data([0x05, 0x06, 0x07, 0x08]), msgStreamId: 20, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType1)
  }

  func testMultipleChunksWithType2() async throws {
    let encoder = MessageEncoder()
    try await encoder.setChunkSize(chunkSize: 4)

    // First message: Type1 for first chunk, Type3 for subsequent
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: false)
    XCTAssertEqual(chunks1.count, 2)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType1)
    XCTAssertTrue(chunks1[1].chunkHeader.messageHeader is MessageHeaderType3)

    // Second message: Type2 for first chunk, Type3 for subsequent
    let message2 = AudioMessage(data: Data([0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertEqual(chunks2.count, 2)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType2)
    XCTAssertTrue(chunks2[1].chunkHeader.messageHeader is MessageHeaderType3)
  }

  func testType0ForceUsage() async throws {
    let encoder = MessageEncoder()

    // First message with Type0
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: true)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType0)
    let header1 = chunks1[0].chunkHeader.messageHeader as! MessageHeaderType0
    XCTAssertEqual(header1.messageStreamId, 10)

    // Second message: even with same attributes, Type0 overrides Type2 when forced
    let message2 = AudioMessage(data: Data([0x05, 0x06, 0x07, 0x08]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: true)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType0)
  }

  func testType2AfterType0() async throws {
    let encoder = MessageEncoder()

    // First message: Type0
    let message1 = AudioMessage(data: Data([0x01, 0x02, 0x03, 0x04]), msgStreamId: 10, timestamp: 1000)
    let chunks1 = await encoder.encode(message: message1, isFirstType0: true)
    XCTAssertTrue(chunks1[0].chunkHeader.messageHeader is MessageHeaderType0)

    // Second message: should use Type2 (same attributes after Type0)
    let message2 = AudioMessage(data: Data([0x05, 0x06, 0x07, 0x08]), msgStreamId: 10, timestamp: 1033)
    let chunks2 = await encoder.encode(message: message2, isFirstType0: false)
    XCTAssertTrue(chunks2[0].chunkHeader.messageHeader is MessageHeaderType2)
  }
}
