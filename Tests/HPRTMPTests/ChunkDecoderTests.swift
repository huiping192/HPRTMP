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
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0() throws {
    // Given
    let data = Data([0x00])
    let decoder = ChunkEncoderTest()
    
    // When
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0WithEncoder() throws {
    let basicHeader = BasicHeader(streamId: 63, type: .type0)
    let data = basicHeader.encode()
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
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
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
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
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
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
    let (header, length) = decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 3)
    XCTAssertEqual(header?.streamId, 320)
    XCTAssertEqual(header?.type, .type1)
  }
  
  
  func testMessageHeaderType0() {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x12, 0x34, 0x56, 0x78, 0x00]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertEqual(length, 11)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, Data([0x02, 0x01, 0x00, 0x00]).uint32)
    XCTAssertEqual(headerType0.messageLength, 0x000004)
    XCTAssertEqual(headerType0.type, MessageType.data(type: .amf0))
    let streamId = Data([0x00, 0x78, 0x56, 0x34]).uint32
    XCTAssertEqual(headerType0.messageStreamId, Int(streamId))
  }
  
  func testMessageHeaderType0WithEncode() {
    let messageHeaderType0 = MessageHeaderType0(timestamp: 32, messageLength: 100, type: .audio, messageStreamId: 5)
    let data = messageHeaderType0.encode()
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: data, type: .type0)
    XCTAssertEqual(length, 11)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 32)
    XCTAssertEqual(headerType0.messageLength, 100)
    XCTAssertEqual(headerType0.type, .audio)
    XCTAssertEqual(headerType0.messageStreamId, 5)
  }
  
  func testMessageHeaderType0ExtendTimestamp() {
    let data: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x01, 0x00, 0x04, 0x12, 0x34, 0x56, 0x78, 0xff, 0xff, 0xff, 0xff]

    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertEqual(length, 15)
    XCTAssertTrue(header is MessageHeaderType0)
    
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 4294967295)
  }
  
  func testMessageHeaderType0ExtendTimestampWithEncode() {
    let messageHeaderType0 = MessageHeaderType0(timestamp: 32 + maxTimestamp, messageLength: 100, type: .audio, messageStreamId: 5)
    let data = messageHeaderType0.encode()
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: data, type: .type0)
    XCTAssertEqual(length, 15)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 32 + maxTimestamp)
    XCTAssertEqual(headerType0.messageLength, 100)
    XCTAssertEqual(headerType0.type, .audio)
    XCTAssertEqual(headerType0.messageStreamId, 5)
  }
  
  func testMessageHeaderType1() {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type1)
    XCTAssertEqual(length, 7)
    XCTAssertTrue(header is MessageHeaderType1)
    let headerType1 = header as! MessageHeaderType1
    XCTAssertEqual(headerType1.timestampDelta, Data([0x02, 0x01, 0x00, 0x00]).uint32)
    XCTAssertEqual(headerType1.messageLength, 0x000004)
    XCTAssertEqual(headerType1.type, .abort)
  }
  
  func testMessageHeaderType1WithEncode() {
    let messageHeaderType1 = MessageHeaderType1(timestampDelta: 1234, messageLength: 456, type: .video)
    let data = messageHeaderType1.encode()
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: data, type: .type1)
    XCTAssertEqual(length, 7)
    XCTAssertTrue(header is MessageHeaderType1)
    let headerType1 = header as! MessageHeaderType1
    XCTAssertEqual(headerType1.timestampDelta, 1234)
    XCTAssertEqual(headerType1.messageLength, 456)
    XCTAssertEqual(headerType1.type, .video)
  }
  
  func testMessageHeaderType2() {
    let data: [UInt8] = [0x00, 0x01, 0x02]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type2)
    XCTAssertEqual(length, 3)
    XCTAssertTrue(header is MessageHeaderType2)
    let headerType2 = header as! MessageHeaderType2
    XCTAssertEqual(headerType2.timestampDelta, Data([0x02, 0x01, 0x00, 0x00]).uint32)
  }
  
  func testMessageHeaderType2WithEncode() {
    let messageHeaderType2 = MessageHeaderType2(timestampDelta: 1234)
    let data = messageHeaderType2.encode()
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: data, type: .type2)
    XCTAssertEqual(length, 3)
    XCTAssertTrue(header is MessageHeaderType2)
    let headerType2 = header as! MessageHeaderType2
    XCTAssertEqual(headerType2.timestampDelta, 1234)
  }
  
  
  func testMessageHeaderType3() {
    let data: [UInt8] = []
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type3)
    XCTAssertEqual(length, 0)
    XCTAssertTrue(header is MessageHeaderType3)
  }
  
  func testMessageHeaderType3WithEncode() {
    let messageHeaderType3 = MessageHeaderType3()
    let data = messageHeaderType3.encode()
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: data, type: .type3)
    XCTAssertEqual(length, 0)
    XCTAssertTrue(header is MessageHeaderType3)
  }
  
  func testMessageHeaderType0InvalidData() {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x12, 0x34, 0x56]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testMessageHeaderType1InvalidData() {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type1)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testMessageHeaderType2InvalidData() {
    let data: [UInt8] = [0x00, 0x01]
    
    let decoder = ChunkEncoderTest()
    
    let (header, length) = decoder.decodeMessageHeader(data: Data(data), type: .type2)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
}
