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
    let headers = encoder.chunk(message: message, isFirstType0: true)
    
    // Then
    XCTAssertEqual(headers.count, 1)
    let header = headers[0]
    
    XCTAssertTrue(header.messageHeader is MessageHeaderType0)
    let messageHeader = header.messageHeader as! MessageHeaderType0
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.messageStreamId, 10)
    XCTAssertEqual(messageHeader.timestamp, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, .audio)
    XCTAssertEqual(header.chunkPayload, Data([0x01, 0x02, 0x03, 0x04]))
  }
  
  func testSingleChunkNotFirst() throws {
    let message = AudioMessage(msgStreamId: 10, data: Data([0x01, 0x02, 0x03, 0x04]), timestamp: 1234)
    let encoder = ChunkEncoder()
    
    // When
    let headers = encoder.chunk(message: message, isFirstType0: false)
    
    // Then
    XCTAssertEqual(headers.count, 1)
    let header = headers[0]
    
    XCTAssertTrue(header.messageHeader is MessageHeaderType1)
    let messageHeader = header.messageHeader as! MessageHeaderType1
    XCTAssertEqual(header.basicHeader.streamId, UInt16(RTMPStreamId.audio.rawValue))
    XCTAssertEqual(messageHeader.timestampDelta, 1234)
    XCTAssertEqual(messageHeader.messageLength, 4)
    XCTAssertEqual(messageHeader.type, .audio)
    XCTAssertEqual(header.chunkPayload, Data([0x01, 0x02, 0x03, 0x04]))
  }
  
  func testChunk_multipleChunks() throws {
    let message = AudioMessage(msgStreamId: 10, data: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]), timestamp: 1234)
    let encoder = ChunkEncoder()
    encoder.chunkSize = 4
    
    // When
    let headers = encoder.chunk(message: message)
    
    // Then
    XCTAssertEqual(headers.count, 2)
    
    let header0 = headers[0]
    XCTAssertTrue(header0.messageHeader is MessageHeaderType0)
    let messageHeader0 = header0.messageHeader as! MessageHeaderType0
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(messageHeader0.timestamp, 1234)
    XCTAssertEqual(messageHeader0.messageLength, 8)
    XCTAssertEqual(messageHeader0.type, .audio)
    XCTAssertEqual(messageHeader0.messageStreamId, 10)
    XCTAssertEqual(header0.chunkPayload, Data([0x01, 0x02, 0x03, 0x04]))
    
    let header1 = headers[1]
    XCTAssertTrue(header1.messageHeader is MessageHeaderType3)
    let messageHeader1 = header1.messageHeader as! MessageHeaderType3
    XCTAssertEqual(messageHeader1.encode().count, 0)
    XCTAssertEqual(header1.chunkPayload, Data([0x05, 0x06, 0x07, 0x08]))
  }
}
