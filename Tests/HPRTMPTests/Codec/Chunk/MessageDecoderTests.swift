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
  
  
  func testDecodeMessage_InterleavedStreams() async {
    // Test that multiple streams (audio/video) can be assembled concurrently
    // when their chunks are interleaved
    let decoder = MessageDecoder()

    // Audio stream: 3 chunks, total 300 bytes
    let audioStreamId: UInt16 = 4
    let audioMsgStreamId = 1
    let audioTimestamp: UInt32 = 100

    // Video stream: 2 chunks, total 200 bytes
    let videoStreamId: UInt16 = 6
    let videoMsgStreamId = 1
    let videoTimestamp: UInt32 = 200

    // Audio chunk 1 (Type 0 header, 128 bytes payload)
    let audioHeader1 = MessageHeaderType0(timestamp: audioTimestamp, messageLength: 300, type: .audio, messageStreamId: audioMsgStreamId)
    var audioPayload1 = Data()
    (0..<128).forEach { _ in audioPayload1.write(UInt8(0xAA)) }
    let audioChunk1 = Chunk(
      chunkHeader: ChunkHeader(basicHeader: BasicHeader(streamId: audioStreamId, type: .type0), messageHeader: audioHeader1),
      chunkData: audioPayload1
    )

    // Video chunk 1 (Type 0 header, 128 bytes payload)
    let videoHeader1 = MessageHeaderType0(timestamp: videoTimestamp, messageLength: 200, type: .video, messageStreamId: videoMsgStreamId)
    var videoPayload1 = Data()
    (0..<128).forEach { _ in videoPayload1.write(UInt8(0xBB)) }
    let videoChunk1 = Chunk(
      chunkHeader: ChunkHeader(basicHeader: BasicHeader(streamId: videoStreamId, type: .type0), messageHeader: videoHeader1),
      chunkData: videoPayload1
    )

    // Audio chunk 2 (Type 3 header, 128 bytes payload)
    var audioPayload2 = Data()
    (0..<128).forEach { _ in audioPayload2.write(UInt8(0xAA)) }
    let audioChunk2 = Chunk(
      chunkHeader: ChunkHeader(basicHeader: BasicHeader(streamId: audioStreamId, type: .type3), messageHeader: MessageHeaderType3()),
      chunkData: audioPayload2
    )

    // Video chunk 2 (Type 3 header, 72 bytes payload - completes the 200 byte message)
    var videoPayload2 = Data()
    (0..<72).forEach { _ in videoPayload2.write(UInt8(0xBB)) }
    let videoChunk2 = Chunk(
      chunkHeader: ChunkHeader(basicHeader: BasicHeader(streamId: videoStreamId, type: .type3), messageHeader: MessageHeaderType3()),
      chunkData: videoPayload2
    )

    // Audio chunk 3 (Type 3 header, 44 bytes payload - completes the 300 byte message)
    var audioPayload3 = Data()
    (0..<44).forEach { _ in audioPayload3.write(UInt8(0xAA)) }
    let audioChunk3 = Chunk(
      chunkHeader: ChunkHeader(basicHeader: BasicHeader(streamId: audioStreamId, type: .type3), messageHeader: MessageHeaderType3()),
      chunkData: audioPayload3
    )

    // Send chunks in interleaved order: audio1, video1, audio2, video2, audio3
    let interleavedData = audioChunk1.encode() + videoChunk1.encode() + audioChunk2.encode() + videoChunk2.encode() + audioChunk3.encode()

    await decoder.append(interleavedData)

    // First decode should return the first completed message (video, 200 bytes)
    let message1 = await decoder.decode()
    XCTAssertNotNil(message1)
    XCTAssertTrue(message1 is VideoMessage)
    let videoMessage = message1 as? VideoMessage
    XCTAssertEqual(videoMessage?.data.count, 200)
    XCTAssertEqual(videoMessage?.timestamp, videoTimestamp)
    XCTAssertEqual(videoMessage?.msgStreamId, videoMsgStreamId)

    // Verify all bytes are 0xBB
    let videoBytes = videoMessage?.data.map { $0 } ?? []
    XCTAssertTrue(videoBytes.allSatisfy { $0 == 0xBB })

    // Second decode should return the audio message (300 bytes)
    let message2 = await decoder.decode()
    XCTAssertNotNil(message2)
    XCTAssertTrue(message2 is AudioMessage)
    let audioMessage = message2 as? AudioMessage
    XCTAssertEqual(audioMessage?.data.count, 300)
    XCTAssertEqual(audioMessage?.timestamp, audioTimestamp)
    XCTAssertEqual(audioMessage?.msgStreamId, audioMsgStreamId)

    // Verify all bytes are 0xAA
    let audioBytes = audioMessage?.data.map { $0 } ?? []
    XCTAssertTrue(audioBytes.allSatisfy { $0 == 0xAA })
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
