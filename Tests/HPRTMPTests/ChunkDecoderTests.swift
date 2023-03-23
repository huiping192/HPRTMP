//
//  ChunkDecoderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class ChunkDecoderTests: XCTestCase {
  
  // test decode chunk data   
  
  
  
  func testBasicHeaderEmptyData() async throws {
    // Given
    let data = Data()
    let decoder = ChunkDecoder()
    
    // When
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0() async throws {
    // Given
    let data = Data([0x00])
    let decoder = ChunkDecoder()
    
    // When
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testBasicHeaderFormat0WithEncoder() async throws {
    let basicHeader = BasicHeader(streamId: 63, type: .type0)
    let data = basicHeader.encode()
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 1)
    XCTAssertEqual(header?.streamId, 63)
    XCTAssertEqual(header?.type, .type0)
  }
  
  func testBasicHeaderFormat1() async throws {
    // Given
    let data = Data([0b01000000, 0b00000001])
    let decoder = ChunkDecoder()
    
    // When
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 2)
    XCTAssertEqual(header?.streamId, 65)
    XCTAssertEqual(header?.type, .type1)
  }
  
  func testBasicHeaderFormatWithEncoder() async throws {
    // Given
    let basicHeader = BasicHeader(streamId: 65, type: .type1)
    let data = basicHeader.encode()
    let decoder = ChunkDecoder()
    
    // When
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 2)
    XCTAssertEqual(header?.streamId, 65)
    XCTAssertEqual(header?.type, .type1)
  }
  
  func testBasicHeaderFormat2() async throws {
    let basicHeader = BasicHeader(streamId: 320, type: .type1)
    let data = basicHeader.encode()
    let decoder = ChunkDecoder()
    
    // When
    let (header, length) = await decoder.decodeBasicHeader(data: data)
    
    // Then
    XCTAssertNotNil(header)
    XCTAssertEqual(length, 3)
    XCTAssertEqual(header?.streamId, 320)
    XCTAssertEqual(header?.type, .type1)
  }
  
  
  func testMessageHeaderType0() async {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x12, 0x34, 0x56, 0x78, 0x00]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertEqual(length, 11)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, Data([0x02, 0x01, 0x00, 0x00]).uint32)
    XCTAssertEqual(headerType0.messageLength, 0x000004)
    XCTAssertEqual(headerType0.type, MessageType.data(type: .amf0))
    let streamId = Data([0x00, 0x78, 0x56, 0x34]).uint32
    XCTAssertEqual(headerType0.messageStreamId, Int(streamId))
  }
  
  func testMessageHeaderType0WithEncode() async {
    let messageHeaderType0 = MessageHeaderType0(timestamp: 32, messageLength: 100, type: .audio, messageStreamId: 5)
    let data = messageHeaderType0.encode()
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: data, type: .type0)
    XCTAssertEqual(length, 11)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 32)
    XCTAssertEqual(headerType0.messageLength, 100)
    XCTAssertEqual(headerType0.type, .audio)
    XCTAssertEqual(headerType0.messageStreamId, 5)
  }
  
  func testMessageHeaderType0ExtendTimestamp() async {
    let data: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x01, 0x00, 0x04, 0x12, 0x34, 0x56, 0x78, 0xff, 0xff, 0xff, 0xff]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertEqual(length, 15)
    XCTAssertTrue(header is MessageHeaderType0)
    
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 4294967295)
  }
  
  func testMessageHeaderType0ExtendTimestampWithEncode() async {
    let messageHeaderType0 = MessageHeaderType0(timestamp: 32 + maxTimestamp, messageLength: 100, type: .audio, messageStreamId: 5)
    let data = messageHeaderType0.encode()
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: data, type: .type0)
    XCTAssertEqual(length, 15)
    XCTAssertTrue(header is MessageHeaderType0)
    let headerType0 = header as! MessageHeaderType0
    XCTAssertEqual(headerType0.timestamp, 32 + maxTimestamp)
    XCTAssertEqual(headerType0.messageLength, 100)
    XCTAssertEqual(headerType0.type, .audio)
    XCTAssertEqual(headerType0.messageStreamId, 5)
  }
  
  func testMessageHeaderType1() async {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x02]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type1)
    XCTAssertEqual(length, 7)
    XCTAssertTrue(header is MessageHeaderType1)
    let headerType1 = header as! MessageHeaderType1
    XCTAssertEqual(headerType1.timestampDelta, Data([0x02, 0x01, 0x00, 0x00]).uint32)
    XCTAssertEqual(headerType1.messageLength, 0x000004)
    XCTAssertEqual(headerType1.type, .abort)
  }
  
  func testMessageHeaderType1WithEncode() async {
    let messageHeaderType1 = MessageHeaderType1(timestampDelta: 1234, messageLength: 456, type: .video)
    let data = messageHeaderType1.encode()
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: data, type: .type1)
    XCTAssertEqual(length, 7)
    XCTAssertTrue(header is MessageHeaderType1)
    let headerType1 = header as! MessageHeaderType1
    XCTAssertEqual(headerType1.timestampDelta, 1234)
    XCTAssertEqual(headerType1.messageLength, 456)
    XCTAssertEqual(headerType1.type, .video)
  }
  
  func testMessageHeaderType2() async {
    let data: [UInt8] = [0x00, 0x01, 0x02]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type2)
    XCTAssertEqual(length, 3)
    XCTAssertTrue(header is MessageHeaderType2)
    let headerType2 = header as! MessageHeaderType2
    XCTAssertEqual(headerType2.timestampDelta, Data([0x02, 0x01, 0x00, 0x00]).uint32)
  }
  
  func testMessageHeaderType2WithEncode() async {
    let messageHeaderType2 = MessageHeaderType2(timestampDelta: 1234)
    let data = messageHeaderType2.encode()
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: data, type: .type2)
    XCTAssertEqual(length, 3)
    XCTAssertTrue(header is MessageHeaderType2)
    let headerType2 = header as! MessageHeaderType2
    XCTAssertEqual(headerType2.timestampDelta, 1234)
  }
  
  
  func testMessageHeaderType3() async {
    let data: [UInt8] = []
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type3)
    XCTAssertEqual(length, 0)
    XCTAssertTrue(header is MessageHeaderType3)
  }
  
  func testMessageHeaderType3WithEncode() async {
    let messageHeaderType3 = MessageHeaderType3()
    let data = messageHeaderType3.encode()
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: data, type: .type3)
    XCTAssertEqual(length, 0)
    XCTAssertTrue(header is MessageHeaderType3)
  }
  
  func testMessageHeaderType0InvalidData() async {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04, 0x12, 0x34, 0x56]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type0)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testMessageHeaderType1InvalidData() async {
    let data: [UInt8] = [0x00, 0x01, 0x02, 0x00, 0x00, 0x04]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type1)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testMessageHeaderType2InvalidData() async {
    let data: [UInt8] = [0x00, 0x01]
    
    let decoder = ChunkDecoder()
    
    let (header, length) = await decoder.decodeMessageHeader(data: Data(data), type: .type2)
    XCTAssertNil(header)
    XCTAssertEqual(length, 0)
  }
  
  func testDecodeChunkDataNoEnoughData() async {
    let messageLength = 32
    let data = Data(repeating: 0xff, count: 25)
    
    let decoder = ChunkDecoder()
    
    let (chunkData, chunkSize) = await decoder.decodeChunkData(data: data, messageLength: messageLength)
    
    XCTAssertNil(chunkData)
    XCTAssertEqual(chunkSize, 0)
  }
  
  func testDecodeChunkDataLessThan256() async {
    let messageLength = 32
    let data = Data(repeating: 0xff, count: 256)
    
    let decoder = ChunkDecoder()
    
    let (chunkData, chunkSize) = await decoder.decodeChunkData(data: data, messageLength: messageLength)
    
    XCTAssertEqual(chunkData?.count, 32)
    XCTAssertEqual(chunkSize, 32)
  }
}
