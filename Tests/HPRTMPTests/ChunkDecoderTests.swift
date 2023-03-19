//
//  ChunkDecoderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class ChunkDecoderTests: XCTestCase {
  
  func testDecodeType0() {
    //    let expectation = XCTestExpectation(description: "Waiting for header to decode")
    //
    //    let decoder = ChunkDecoder()
    //    let payload = Data([0x00,0x00,0x01])
    //    let expectedHeader = ChunkHeader(streamId: 2, messageHeader: MessageHeaderType0(timestamp: 5, messageLength: 3, type: .audio, messageStreamId: 0))
    //    let expectedChunk = Chunk(chunkHeader: expectedHeader, chunkData: payload)
    //    var decodedChunk: Chunk?
    //    decoder.decode(data: expectedHeader.encode()) { chunk in
    //      decodedChunk = chunk
    //      expectation.fulfill()
    //    }
    //    wait(for: [expectation], timeout: 2.0)
    //
    //    XCTAssertEqual(decodedChunk, expectedChunk)
  }
  //
  //  func testDecodeType1() {
  //    let decoder = ChunkDecoder()
  //
  //    // Test with basic header size of 1
  //    let type1Data1 = Data([0b01100000, 0x01, 0x02, 0x03, 0x04, 0x05])
  //    let expectedHeader1 = ChunkHeader(streamId: 1,
  //                                      timestampDelta: 515,
  //                                      messageLength: 1030,
  //                                      messageType: MessageType.bytesRead,
  //                                      messageStreamId: 1545,
  //                                      payload: Data(),
  //                                      isChunkComplete: false)
  //    var header1: ChunkHeader?
  //    decoder.decode(data: type1Data1) { header in
  //      header1 = header
  //    }
  //    XCTAssertEqual(header1, expectedHeader1)
  //
  //    // Test with basic header size of 2
  //    let type1Data2 = Data([0b01100100, 0x01, 0x02, 0x03, 0x04, 0x05])
  //    let expectedHeader2 = ChunkHeader(streamId: 1,
  //                                      timestampDelta: 515,
  //                                      messageLength: 1030,
  //                                      messageType: MessageType.bytesRead,
  //                                      messageStreamId: 1545,
  //                                      payload: Data(),
  //                                      isChunkComplete: false)
  //    var header2: ChunkHeader?
  //    decoder.decode(data: type1Data2) { header in
  //      header2 = header
  //    }
  //    XCTAssertEqual(header2, expectedHeader2)
  //
  //    // Test with basic header size of 3
  //    let type1Data3 = Data([0b01100000, 0x01, 0x02, 0x03, 0x04, 0x05])
  //    let expectedHeader3 = ChunkHeader(streamId: 258,
  //                                      timestampDelta: 515,
  //                                      messageLength: 1030,
  //                                      messageType: MessageType.bytesRead,
  //                                      messageStreamId: 1545,
  //                                      payload: Data(),
  //                                      isChunkComplete: false)
  //    var header3: ChunkHeader?
  //    decoder.decode(data: type1Data3) { header in
  //      header3 = header
  //    }
  //    XCTAssertEqual(header3, expectedHeader3)
  //  }
  //
  //  func testDecodeType2() {
  //    let expectation = XCTestExpectation(description: "Waiting for header to decode")
  //
  //    let decoder = ChunkDecoder()
  //    let messageHeaderType2 = MessageHeaderType2(timestampDelta: 5)
  //    let expectedHeader = ChunkHeader(streamId: 2, messageHeader: messageHeaderType2, chunkPayload: Data())
  //    var decodedHeader: ChunkHeader?
  //    decoder.decode(data: expectedHeader.encode()) { header in
  //      decodedHeader = header
  //      expectation.fulfill()
  //    }
  //    wait(for: [expectation], timeout: 2.0)
  //
  //    XCTAssertEqual(decodedHeader, expectedHeader)
  //  }
  //
  //  func testDecodeType3() {
  //    let expectation = XCTestExpectation(description: "Waiting for header to decode")
  //
  //    let decoder = ChunkDecoder()
  //    let expectedHeader = ChunkHeader(streamId: 2, messageHeader: MessageHeaderType3(), chunkPayload: Data())
  //    var decodedHeader: ChunkHeader?
  //    decoder.decode(data: expectedHeader.encode()) { header in
  //      decodedHeader = header
  //      expectation.fulfill()
  //    }
  //    wait(for: [expectation], timeout: 2.0)
  //
  //    XCTAssertEqual(decodedHeader, expectedHeader)
  //  }
  
  
  func testBasicHeaderEmptyData() throws {
    // Given
    let data = Data()
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.basicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0() throws {
    // Given
    let data = Data([0x00])
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.basicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0WithEncoder() throws {
    let basicHeader = BasicHeader(streamId: 63, type: .type0)
    let data = basicHeader.encode()
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.basicHeader(data: data)
    
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 1)
    XCTAssertEqual(header?.streamId, 63)
    XCTAssertEqual(header?.type, .type0)
  }
  
  func testBasicHeaderFormat1() throws {
    // Given
    let data = Data([0b01000000, 0b00000001])
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.basicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 2)
    XCTAssertEqual(header?.streamId, 65)
    XCTAssertEqual(header?.type, .type1)
  }
  
  func testBasicHeaderFormatWithEncoder() throws {
    // Given
    let basicHeader = BasicHeader(streamId: 65, type: .type1)
    let data = basicHeader.encode()
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.basicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 2)
    XCTAssertEqual(header?.streamId, 65)
    XCTAssertEqual(header?.type, .type1)
  }
  
  func testBasicHeaderFormat2() throws {
    let basicHeader = BasicHeader(streamId: 320, type: .type1)
    let data = basicHeader.encode()
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.basicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 3)
    XCTAssertEqual(header?.streamId, 320)
    XCTAssertEqual(header?.type, .type1)
  }
  
}
