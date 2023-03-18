//
//  ChunkEncoderTests.swift
//  
//
//  Created by 郭 輝平 on 2023/03/18.
//

import XCTest
@testable import HPRTMP

final class ChunkEncoderTests: XCTestCase {
  
  func testSingleChunkFirst() throws {
    let message = AudioMessage(msgStreamId: 10, data: Data([0x01, 0x02, 0x03, 0x04]), timestamp: 1234)
    let encoder = ChunkEncoder()
    
    // When
    let chunks = encoder.chunk(message: message, isFirstType0: true)
    
    // Then
    XCTAssertEqual(chunks.count, 1)
    let firstChunk = chunks[0]
    let header = firstChunk.chunkHeader
    XCTAssertTrue(header.messageHeader is MessageHeaderType0)
    let messageHeader = header.messageHeader as! MessageHeaderType0
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.messageStreamId, 10)
    XCTAssertEqual(messageHeader.timestamp, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, .audio)
    XCTAssertEqual(firstChunk.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
  }
  
  func testSingleChunkNotFirst() throws {
    let message = AudioMessage(msgStreamId: 10, data: Data([0x01, 0x02, 0x03, 0x04]), timestamp: 1234)
    let encoder = ChunkEncoder()
    
    // When
    let chunks = encoder.chunk(message: message, isFirstType0: false)
    
    // Then
    XCTAssertEqual(chunks.count, 1)
    let firstChunk = chunks[0]
    let header = firstChunk.chunkHeader
    XCTAssertTrue(header.messageHeader is MessageHeaderType1)
    let messageHeader = header.messageHeader as! MessageHeaderType1
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.timestampDelta, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, .audio)
    XCTAssertEqual(firstChunk.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
  }
  
  func testChunk_multipleChunks() throws {
    let message = AudioMessage(msgStreamId: 10, data: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]), timestamp: 1234)
    let encoder = ChunkEncoder()
    encoder.chunkSize = 4
    
    // When
    let chunks = encoder.chunk(message: message)
    
    // Then
    XCTAssertEqual(chunks.count, 2)
    
    let chunk0 = chunks[0]
    let header0 = chunk0.chunkHeader
    XCTAssertTrue(header0.messageHeader is MessageHeaderType0)
    let messageHeader0 = header0.messageHeader as! MessageHeaderType0
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(messageHeader0.timestamp, 1234)
    XCTAssertEqual(messageHeader0.messageLength, 8)
    XCTAssertEqual(messageHeader0.type, .audio)
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(chunk0.chunkData, Data([0x01, 0x02, 0x03, 0x04]))
    
    let chunk1 = chunks[1]
    let header1 = chunk1.chunkHeader
    XCTAssertTrue(header1.messageHeader is MessageHeaderType3)
    let messageHeader1 = header1.messageHeader as! MessageHeaderType3
    XCTAssertEqual(messageHeader1.encode().count, 0)
    XCTAssertEqual(chunk1.chunkData, Data([0x05, 0x06, 0x07, 0x08]))
  }
}
