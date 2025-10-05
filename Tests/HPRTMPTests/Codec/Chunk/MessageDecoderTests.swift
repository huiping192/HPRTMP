//
//  MessageDecoderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class MessageDecoderTests: XCTestCase {
  func testDecodeMessage_SingleChunk() async {
    let decoder = MessageDecoder()

    // Prepare your test data here, which should be a Data object containing a single RTMP chunk.
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 9, type: .audio, messageStreamId: 15)

    var payload = Data()
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)
    payload.writeU24(1, bigEndian: true)

    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)
    let data = targetChunk.encode()

    await decoder.append(data)
    let message = await decoder.decode()

    XCTAssertNotNil(message)
    XCTAssertTrue(message is AudioMessage)
    let audioMessage = message as? AudioMessage
    XCTAssertEqual(audioMessage?.data, payload)
    XCTAssertEqual(audioMessage?.timestamp, 100)
    XCTAssertEqual(audioMessage?.msgStreamId, 15)
  }
  func testDecodeMessage_MultipleChunks() async {
    let decoder = MessageDecoder()

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

    await decoder.append(data)
    let message = await decoder.decode()

    XCTAssertNotNil(message)
    XCTAssertTrue(message is AudioMessage)
    let audioMessage = message as? AudioMessage
    XCTAssertEqual(audioMessage?.data.count, 307)
    XCTAssertEqual(audioMessage?.timestamp, 100)
    XCTAssertEqual(audioMessage?.msgStreamId, 15)
  }
  
  func testDecodeMessage_InvalidData() async {
    let decoder = MessageDecoder()
    let basicHeader = BasicHeader(streamId: 10, type: .type0)
    let targetMessageHeader = MessageHeaderType0(timestamp: 100, messageLength: 307, type: .audio, messageStreamId: 15)

    var payload = Data()
    (0..<128).forEach { _ in
      payload.write(UInt8(1))
    }

    let targetChunk = Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: targetMessageHeader), chunkData: payload)

    let data = targetChunk.chunkData

    await decoder.append(data)
    let message = await decoder.decode()

    XCTAssertNil(message)
  }
  
  
  func testCreateMessage() async {
    let decoder = MessageDecoder()
    
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
    
    let commandMessagePayload: Data = "connect".amf0Value + 5.amf0Value + ["object":"haha"].afm0Value + ["info": "test"].afm0Value
    let commandMessage = await decoder.createMessage(chunkStreamId: chunkStreamId, msgStreamId: msgStreamId, messageType: .command(type: .amf0), timestamp: timestamp, chunkPayload: commandMessagePayload)
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
}
