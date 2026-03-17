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

  func testDecodeChunkWithEmptyData() async {
    let data = Data()
    let decoder = ChunkDecoder()

    await decoder.append(data)
    let result = await decoder.decodeChunk()
    XCTAssertNil(result)  // nil means need more data
  }

  // Add more test cases with valid data inputs representing different scenarios.
  // For example, you can create Data objects with various message header types, chunk sizes,
  // and message lengths, then test if the decodeChunk function returns the correct output.

  func testDecodeChunkWithValidMessageHeaderType0() async {
    // Prepare Data object with valid MessageHeaderType0
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 9, type: .audio, messageStreamId: MessageStreamId(15))

    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)

    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    let decoder = ChunkDecoder()

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type0)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType0)

    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType0
    XCTAssertEqual(messageHeader?.timestamp.value, 100)
    XCTAssertEqual(messageHeader?.messageLength, 9)
    XCTAssertEqual(messageHeader?.messageStreamId.value, 15)
    XCTAssertEqual(messageHeader?.type, .audio)

    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)
  }

  func testDecodeChunkWithValidMessageHeaderType1() async {
    // Prepare Data object with valid MessageHeaderType1
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type1)
    let targetMessageHeader = MessageHeaderType1(timestampDelta: Timestamp(50), messageLength: 9, type: .video)

    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)

    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    let decoder = ChunkDecoder()

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type1)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType1)

    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType1
    XCTAssertEqual(messageHeader?.timestampDelta.value, 50)
    XCTAssertEqual(messageHeader?.messageLength, 9)
    XCTAssertEqual(messageHeader?.type, .video)
    XCTAssertEqual(chunk?.chunkData, payload)
  }

  func testDecodeChunkWithValidMessageHeaderType2() async {
    let decoder = ChunkDecoder()

    let basicHeader0 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 9, type: .audio, messageStreamId: MessageStreamId(15))

    var payload0 = Data()
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)

    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()

    await decoder.append(chunkData0)
    let _ = await decoder.decodeChunk()

    // Prepare Data object with valid MessageHeaderType2
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type2)
    let targetMessageHeader = MessageHeaderType2(timestampDelta: Timestamp(50))
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)

    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()


    // messageDataLengthMap is now private, so we cannot test it directly
    // We rely on the decodeChunk behavior to ensure it's working correctly

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType2)

    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader?.timestampDelta.value, 50)
    XCTAssertEqual(chunk?.chunkData, payload)
  }

  func testDecodeChunkWithValidMessageHeaderType3() async {
    let decoder = ChunkDecoder()

    let basicHeader0 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 9, type: .audio, messageStreamId: MessageStreamId(15))

    var payload0 = Data()
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)
    payload0.writeU24(1, bigEndian: true)

    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()

    await decoder.append(chunkData0)
    let _ = await decoder.decodeChunk()

    // Prepare Data object with valid MessageHeaderType3
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type3)
    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)

    let targetMessageHeader = MessageHeaderType3()
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    // messageDataLengthMap is now private, so we cannot test it directly
    // We rely on the decodeChunk behavior to ensure it's working correctly

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType3)

    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)
  }

  func testDecodeChunkWithValidMessageHeaderType3WithLongPayload() async {
    let decoder = ChunkDecoder()

    let basicHeader0 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let targetMessageHeader0 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 300, type: .audio, messageStreamId: MessageStreamId(15))

    var payload0 = Data()
    (0..<128).forEach { _ in
      payload0.write(UInt8(1))
    }

    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: targetMessageHeader0), chunkData: payload0)
    let chunkData0 = chunk0.encode()

    await decoder.append(chunkData0)
    let _ = await decoder.decodeChunk()

    // remainDataLengthMap is now private, so we cannot test it directly
    // We rely on the decodeChunk behavior to ensure it's working correctly

    // Prepare Data object with valid MessageHeaderType3
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type3)
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }

    let targetMessageHeader = MessageHeaderType3()
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    // remainDataLengthMap is now private, cannot directly verify
    // But we can verify the chunk was decoded correctly

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType3)

    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk?.chunkData, payload)



    let basicHeader2 = BasicHeader(streamId: ChunkStreamId(10), type: .type3)
    var payload2 = Data()
    (0..<44).forEach { _ in
      payload2.write(UInt8(1))
    }

    let targetMessageHeader2 = MessageHeaderType3()
    let targetChunk2 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader2, messageHeader: targetMessageHeader2), chunkData: payload2)
    let data2 = targetChunk2.encode()

    await decoder.append(data2)
    let chunk2 = await decoder.decodeChunk()

    // remainDataLengthMap is now private, cannot directly verify
    // But we can verify the chunk was decoded correctly and completed the message

    XCTAssertNotNil(chunk2)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.type, MessageHeaderType.type3)
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk2?.chunkHeader.messageHeader is MessageHeaderType3)

    // Test other properties and conditions depending on your specific scenario
    XCTAssertEqual(chunk2?.chunkData, payload2)
  }

  func testDecodeChunkWithValidMessageHeaderType2WithLongPayload() async {
    let decoder = ChunkDecoder()

    let basicHeader1 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let targetMessageHeader1 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 300, type: .audio, messageStreamId: MessageStreamId(15))

    var payload1 = Data()
    (0..<128).forEach { _ in
      payload1.write(UInt8(1))
    }

    let chunk1 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader1, messageHeader: targetMessageHeader1), chunkData: payload1)
    let chunkData1 = chunk1.encode()

    await decoder.append(chunkData1)
    let _ = await decoder.decodeChunk()

    // remainDataLengthMap is now private, so we cannot test it directly
    // We rely on the decodeChunk behavior to ensure it's working correctly

    // Prepare Data object with valid MessageHeaderType2
    let basicHeader = BasicHeader(streamId: ChunkStreamId(10), type: .type2)
    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }

    let targetMessageHeader = MessageHeaderType2(timestampDelta: Timestamp(100))
    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    await decoder.append(data)
    let chunk = await decoder.decodeChunk()

    // remainDataLengthMap is now private, cannot directly verify

    XCTAssertNotNil(chunk)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk?.chunkHeader.messageHeader is MessageHeaderType2)

    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader?.timestampDelta.value, 100)
    XCTAssertEqual(chunk?.chunkData, payload)


    let basicHeader2 = BasicHeader(streamId: ChunkStreamId(10), type: .type2)
    var payload2 = Data()
    (0..<44).forEach { _ in
      payload2.write(UInt8(1))
    }

    let targetMessageHeader2 = MessageHeaderType2(timestampDelta: Timestamp(100))
    let targetChunk2 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader2, messageHeader: targetMessageHeader2), chunkData: payload2)
    let data2 = targetChunk2.encode()

    await decoder.append(data2)
    let chunk2 = await decoder.decodeChunk()

    // remainDataLengthMap is now private, cannot directly verify
    // But we can verify the chunk was decoded correctly and completed the message

    XCTAssertNotNil(chunk2)

    // Test specific properties of the chunk and headers
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.type, .type2)
    XCTAssertEqual(chunk2?.chunkHeader.basicHeader.streamId.value, 10)

    XCTAssertTrue(chunk2?.chunkHeader.messageHeader is MessageHeaderType2)

    let messageHeader2 = chunk2?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader2?.timestampDelta.value, 100)
    XCTAssertEqual(chunk2?.chunkData, payload2)
  }

  
  // MARK: - Extended Timestamp Tests
  
  /// Test Type0 with extended timestamp (when timestamp = 0xFFFFFF)
  func testDecodeChunkWithExtendedTimestampType0() async {
    let decoder = ChunkDecoder()
    
    // Type0 with timestamp = 0xFFFFFF (16777215) triggers extended timestamp
    // Basic header (1 byte): format=0, streamId=10 -> 0b00_001010 = 0x0A
    // Message header (11 bytes): timestamp=0xFFFFFF, length=128, type=audio(8), streamId=1
    // Extended timestamp (4 bytes): actual timestamp
    
    var data = Data()
    // Basic header
    data.append(0x0A)
    // Timestamp (3 bytes) - all 0xFF to trigger extended timestamp
    data.append(contentsOf: [0xFF, 0xFF, 0xFF])
    // Message length (3 bytes) = 128
    data.append(contentsOf: [0x00, 0x00, 0x80])
    // Message type = audio (8)
    data.append(0x08)
    // Message stream ID (4 bytes, little-endian) = 1
    data.append(contentsOf: [0x01, 0x00, 0x00, 0x00])
    // Extended timestamp (4 bytes, big-endian) = 200000
    data.append(contentsOf: [0x00, 0x03, 0x0D, 0x40])
    // Payload (128 bytes)
    (0..<128).forEach { _ in data.append(UInt8(1)) }
    
    await decoder.append(data)
    let chunk = await decoder.decodeChunk()
    
    XCTAssertNotNil(chunk)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type0)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.streamId.value, 10)
    
    // Verify extended timestamp was correctly applied
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType0
    XCTAssertEqual(messageHeader?.timestamp.value, 200000)
    XCTAssertEqual(messageHeader?.messageLength, 128)
    XCTAssertEqual(messageHeader?.type, .audio)
    XCTAssertEqual(chunk?.chunkData.count, 128)
  }
  
  /// Test Type1 with extended timestamp
  func testDecodeChunkWithExtendedTimestampType1() async {
    let decoder = ChunkDecoder()
    
    // First, send a Type0 to establish context
    let basicHeader0 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let header0 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 128, type: .audio, messageStreamId: MessageStreamId(15))
    var payload0 = Data()
    (0..<128).forEach { _ in payload0.append(UInt8(1)) }
    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: header0), chunkData: payload0)
    await decoder.append(chunk0.encode())
    _ = await decoder.decodeChunk()
    
    // Now send Type1 with extended timestamp delta
    var data = Data()
    // Basic header: format=1, streamId=10 -> 0b01_001010 = 0x4A
    data.append(0x4A)
    // Timestamp delta (3 bytes) - all 0xFF to trigger extended timestamp
    data.append(contentsOf: [0xFF, 0xFF, 0xFF])
    // Message length (3 bytes) = 64
    data.append(contentsOf: [0x00, 0x00, 0x40])
    // Message type = video (9)
    data.append(0x09)
    // Extended timestamp delta (4 bytes, big-endian) = 50000
    data.append(contentsOf: [0x00, 0x00, 0xC3, 0x50])
    // Payload (64 bytes)
    (0..<64).forEach { _ in data.append(UInt8(2)) }
    
    await decoder.append(data)
    let chunk = await decoder.decodeChunk()
    
    XCTAssertNotNil(chunk)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type1)
    
    // Verify extended timestamp delta was correctly applied
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType1
    XCTAssertEqual(messageHeader?.timestampDelta.value, 50000)
    XCTAssertEqual(messageHeader?.messageLength, 64)
    XCTAssertEqual(messageHeader?.type, .video)
    XCTAssertEqual(chunk?.chunkData.count, 64)
    
    // Verify stream context was updated correctly
    let contexts = await decoder.streamContexts
    let context = contexts[ChunkStreamId(10)]
    XCTAssertNotNil(context)
    // Absolute timestamp should be 100 (initial) + 50000 (delta) = 50100
    XCTAssertEqual(context?.timestamp.value, 50100)
  }
  
  /// Test Type2 with extended timestamp
  func testDecodeChunkWithExtendedTimestampType2() async {
    let decoder = ChunkDecoder()
    
    // First, send a Type0 to establish context
    let basicHeader0 = BasicHeader(streamId: ChunkStreamId(10), type: .type0)
    let header0 = MessageHeaderType0(timestamp: Timestamp(100), messageLength: 128, type: .audio, messageStreamId: MessageStreamId(15))
    var payload0 = Data()
    (0..<128).forEach { _ in payload0.append(UInt8(1)) }
    let chunk0 = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader0, messageHeader: header0), chunkData: payload0)
    await decoder.append(chunk0.encode())
    _ = await decoder.decodeChunk()
    
    // Now send Type2 with extended timestamp delta
    var data = Data()
    // Basic header: format=2, streamId=10 -> 0b10_001010 = 0x8A
    data.append(0x8A)
    // Timestamp delta (3 bytes) - all 0xFF to trigger extended timestamp
    data.append(contentsOf: [0xFF, 0xFF, 0xFF])
    // Extended timestamp delta (4 bytes, big-endian) = 30000
    data.append(contentsOf: [0x00, 0x00, 0x75, 0x30])
    // Payload (128 bytes)
    (0..<128).forEach { _ in data.append(UInt8(3)) }
    
    await decoder.append(data)
    let chunk = await decoder.decodeChunk()
    
    XCTAssertNotNil(chunk)
    XCTAssertEqual(chunk?.chunkHeader.basicHeader.type, .type2)
    
    // Verify extended timestamp delta was correctly applied
    let messageHeader = chunk?.chunkHeader.messageHeader as? MessageHeaderType2
    XCTAssertEqual(messageHeader?.timestampDelta.value, 30000)
    XCTAssertEqual(chunk?.chunkData.count, 128)
    
    // Verify stream context was updated correctly
    let contexts = await decoder.streamContexts
    let context = contexts[ChunkStreamId(10)]
    XCTAssertNotNil(context)
    // Absolute timestamp should be 100 (initial) + 30000 (delta) = 30100
    XCTAssertEqual(context?.timestamp.value, 30100)
  }
}
