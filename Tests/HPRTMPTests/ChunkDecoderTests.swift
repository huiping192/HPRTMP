//
//  ChunkDecoderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class ChunkDecoderTests: XCTestCase {
  func testDecodeMessage_SingleChunk() async {
    let decoder = ChunkDecoder()
    
    // Prepare your test data here, which should be a Data object containing a single RTMP chunk.
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 9, type: .audio, messageStreamId: 15)
    
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    let (message, chunkSize) = await decoder.decodeMessage(data: data)
    
    XCTAssertNotNil(message)
    XCTAssertTrue(message is AudioMessage)
    let audioMessage = message as? AudioMessage
    XCTAssertEqual(audioMessage?.data, payload)
    XCTAssertEqual(audioMessage?.timestamp, 100)
    XCTAssertEqual(audioMessage?.msgStreamId, 15)
    
    XCTAssertEqual(chunkSize, data.count)
  }
  func testDecodeMessage_MultipleChunks() async {
    let decoder = ChunkDecoder()
    
    // Prepare your test data here, which should be a Data object containing multiple RTMP chunks.
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 307, type: .audio, messageStreamId: 15)
    
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    
    let basicHeader2 = BasicHeader(streamId: 10, type: .type3)
    let messageHeader2 = MessageHeaderType3()
    var payload2 = Data()
    (0..<128).forEach { _ in
      payload2.write(UInt8(1))
    }
    let secondChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader2, messageHeader: messageHeader2), chunkData: payload2)
    
    let basicHeader3 = BasicHeader(streamId: 10, type: .type3)
    let messageHeader3 = MessageHeaderType3()
    var payload3 = Data()
    (0..<51).forEach { _ in
      payload3.write(UInt8(1))
    }
    let chunk3 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader3, messageHeader: messageHeader3), chunkData: payload3)
    
    
    // Encode the target chunk multiple times to simulate multiple chunks in the data.
    let data = targetChunk.encode() + secondChunk.encode() + chunk3.encode()
    
    let (message, chunkSize) = await decoder.decodeMessage(data: data)
    
    XCTAssertNotNil(message)
    XCTAssertTrue(message is AudioMessage)
    let audioMessage = message as? AudioMessage
    XCTAssertEqual(audioMessage?.data.count, 307)
    XCTAssertEqual(audioMessage?.timestamp, 100)
    XCTAssertEqual(audioMessage?.msgStreamId, 15)
    
    // Adjust the expected chunk size based on the number of chunks in the test data.
    XCTAssertEqual(chunkSize, data.count)
  }
  
  func testDecodeMessage_InvalidData() async {
    let decoder = ChunkDecoder()
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 307, type: .audio, messageStreamId: 15)
    
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    
    let data = targetChunk.chunkData
    
    let (message, chunkSize) = await decoder.decodeMessage(data: data)
    
    XCTAssertNil(message)
    XCTAssertEqual(chunkSize, 0)
  }
  
  
  func testCreateMessage() async {
    let decoder = ChunkDecoder()
    
    let chunkStreamId: UInt16 = 1
    let msgStreamId = 1
    let timestamp: UInt32 = 100
    let chunkPayload = Data([0, 1, 2, 3])
    
    let chunkSizeMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .chunkSize, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(chunkSizeMessage is ChunkSizeMessage)
    
    let controlMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .control, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(controlMessage is ControlMessage)
    
    let peerBandwidthMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .peerBandwidth, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(peerBandwidthMessage is PeerBandwidthMessage)
    
    let commandMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .command(type: .amf0), timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(commandMessage is CommandMessage)
    
    let dataMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .data(type: .amf0), timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(dataMessage is DataMessage)
    
    let audioMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .audio, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(audioMessage is AudioMessage)
    
    let videoMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .video, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(videoMessage is VideoMessage)
    
    let abortMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .abort, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(abortMessage is AbortMessage)
    
    let acknowledgementMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .acknowledgement, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(acknowledgementMessage is AcknowledgementMessage)
    
    let windowAckMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .windowAcknowledgement, timestamp: timestamp, chunkPayload: chunkPayload)
    XCTAssertTrue(windowAckMessage is WindowAckMessage)
  }
  
  
  // test decode chunk data
  
  func testDecodeChunkWithEmptyData() async {
    let data = Data()
    let decoder = ChunkDecoder()
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    XCTAssertNil(chunk)
    XCTAssertEqual(size, 0)
  }
  
  // Add more test cases with valid data inputs representing different scenarios.
  // For example, you can create Data objects with various message header types, chunk sizes,
  // and message lengths, then test if the decodeChunk function returns the correct output.
  
  func testDecodeChunkWithValidMessageHeaderType0() async {
    // Prepare Data object with valid MessageHeaderType0
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 9, type: .audio, messageStreamId: 15)
    
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    let decoder = ChunkDecoder()
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type0)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType0)
    
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType0
    XCTAssertEqual(messageHeader?.timestamp, 100)
    XCTAssertEqual(messageHeader?.messageLength, 9)
    XCTAssertEqual(messageHeader?.messageStreamId, 15)
    XCTAssertEqual(messageHeader?.type, .audio)
    
    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)
  }
  
  func testDecodeChunkWithValidMessageHeaderType1() async {
    // Prepare Data object with valid MessageHeaderType1
    let basicHeader = BasicHeader(streamId: 10, type: .type1)
    let targetMessageHeader = MessageHeaderType1(timestampDelta: 50, messageLength: 9, type: .video)
    
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    let decoder = ChunkDecoder()
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type1)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType1)
    
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType1
    XCTAssertEqual(messageHeader?.timestampDelta, 50)
    XCTAssertEqual(messageHeader?.messageLength, 9)
    XCTAssertEqual(messageHeader?.type, .video)
    XCTAssertEqual(chunk?.chunkData, payload)
  }
  
  func testDecodeChunkWithValidMessageHeaderType2() async {
    let decoder = ChunkDecoder()
    
    let basicHeader0 = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: 100, messageLength: 9, type: .audio, messageStreamId: 15)
    
    var payload0 = Data()
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    
    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()
    
    let _ = await decoder.decodeChunk(data: chunkData0)
    
    // Prepare Data object with valid MessageHeaderType2
    let basicHeader = BasicHeader(streamId: 10, type: .type2)
    let targetMessageHeader = MessageHeaderType2(timestampDelta: 50)
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    
    // Assume a previous chunk with same streamId and messageLength exists
    let messageLength = await decoder.messageDataLengthMap[10]
    XCTAssertEqual(messageLength, 9)
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType2)
    
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader?.timestampDelta, 50)
    XCTAssertEqual(chunk?.chunkData, payload)
  }
  
  func testDecodeChunkWithValidMessageHeaderType3() async {
    let decoder = ChunkDecoder()
    
    let basicHeader0 = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: 100, messageLength: 9, type: .audio, messageStreamId: 15)
    
    var payload0 = Data()
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    
    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()
    
    let _ = await decoder.decodeChunk(data: chunkData0)
    
    // Prepare Data object with valid MessageHeaderType3
    let basicHeader = BasicHeader(streamId: 10, type: .type3)
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    
    let targetMessageHeader = MessageHeaderType3()
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    // Assume a previous chunk with same streamId and messageLength exists
    let messageLength = await decoder.messageDataLengthMap[10]
    XCTAssertEqual(messageLength, 9)
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType3)
    
    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)
  }
  
  func testDecodeChunkWithValidMessageHeaderType3WithLongPayload() async {
    let decoder = ChunkDecoder()
    
    let basicHeader0 = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: 100, messageLength: 300, type: .audio, messageStreamId: 15)
    
    var payload0 = Data()
    (0..<128).forEach { _ in
      payload0.write(UInt8(1))
    }
    
    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()
    
    let _ = await decoder.decodeChunk(data: chunkData0)
    
    var remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, 300 - 128)
    
    // Prepare Data object with valid MessageHeaderType3
    let basicHeader = BasicHeader(streamId: 10, type: .type3)
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }
    
    let targetMessageHeader = MessageHeaderType3()
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    
    remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, 300 - 128 - 128)
    
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType3)
    
    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)
    
    
    
    let basicHeader2 = BasicHeader(streamId: 10, type: .type3)
    var payload2 = Data()
    (0..<44).forEach { _ in
      payload2.write(UInt8(1))
    }
    
    let targetMessageHeader2 = MessageHeaderType3()
    let targetChunk2 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader2, messageHeader: targetMessageHeader2), chunkData: payload2)
    let data2 = targetChunk2.encode()
    
    let (chunk2, size2) = await decoder.decodeChunk(data: data2)
    
    remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, nil)
    
    XCTAssertNotNil(chunk2)
    XCTAssertEqual(size2, data2.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk2?.chunkHeader.messageHeader is MessageHeaderType3)
    
    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk2?.chunkData, payload2)
  }
  
  func testDecodeChunkWithValidMessageHeaderType2WithLongPayload() async {
    let decoder = ChunkDecoder()
    
    let basicHeader1 = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader1 = MessageHeaderType0(timestamp: 100, messageLength: 300, type: .audio, messageStreamId: 15)
    
    var payload1 = Data()
    (0..<128).forEach { _ in
      payload1.write(UInt8(1))
    }
    
    let chunk1 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader1, messageHeader: targetMessageHeader1), chunkData: payload1)
    let chunkData1 = chunk1.encode()
    
    let _ = await decoder.decodeChunk(data: chunkData1)
    
    var remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, 300 - 128)
    
    // Prepare Data object with valid MessageHeaderType3
    let basicHeader = BasicHeader(streamId: 10, type: .type2)
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }
    
    let targetMessageHeader = MessageHeaderType2(timestampDelta: 100)
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()
    
    let (chunk, size) = await decoder.decodeChunk(data: data)
    
    remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, 300 - 128 - 128)
    
    XCTAssertNotNil(chunk)
    XCTAssertEqual(size, data.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType2)
    
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader?.timestampDelta, 100)
    XCTAssertEqual(chunk?.chunkData, payload)
    
    
    let basicHeader2 = BasicHeader(streamId: 10, type: .type2)
    var payload2 = Data()
    (0..<44).forEach { _ in
      payload2.write(UInt8(1))
    }
    
    let targetMessageHeader2 = MessageHeaderType2(timestampDelta: 100)
    let targetChunk2 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader2, messageHeader: targetMessageHeader2), chunkData: payload2)
    let data2 = targetChunk2.encode()
    
    let (chunk2, size2) = await decoder.decodeChunk(data: data)
    
    remainMessageLength = await decoder.remainDataLengthMap[10]
    XCTAssertEqual(remainMessageLength, nil)
    
    XCTAssertNotNil(chunk2)
    XCTAssertEqual(size2, data2.count)
    
    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.streamId, 10)
    
    XCTAssertTrue(chunk2?.chunkHeader.messageHeader is MessageHeaderType2)
    
    let messageHeader2 = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader2?.timestampDelta, 100)
    XCTAssertEqual(chunk2?.chunkData, payload2)
  }
  
  
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
