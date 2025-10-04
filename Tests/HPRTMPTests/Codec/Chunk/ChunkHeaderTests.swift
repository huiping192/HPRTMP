//
//  ChunkHeaderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/06.
//

import XCTest
@testable import HPRTMP

final class ChunkTests: XCTestCase {

  func testEncode() {
    let streamId: UInt16 = 1
    let messageHeader = MessageHeaderType0(timestamp: 1, messageLength: 1, type: .video, messageStreamId: Int(streamId))
    let chunkPayload = Data([0x00, 0x01, 0x02, 0x03])
    let chunkHeader = ChunkHeader(streamId: streamId, messageHeader: messageHeader)
    let chunk = Chunk(chunkHeader: chunkHeader, chunkData: chunkPayload)
    let encodedData = chunk.encode()

    let basicHeader = BasicHeader(streamId: UInt16(streamId), type: .type0)
    let expectedData = basicHeader.encode() + messageHeader.encode() + chunkPayload
    XCTAssertEqual(encodedData, expectedData)
  }

  func testBasicHeaderType() {
    let streamId: UInt16 = 2
    let messageHeaderType1 = MessageHeaderType1(timestampDelta: 1, messageLength: 1, type: .audio)
    let chunkHeader = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType1)

    XCTAssertEqual(chunkHeader.basicHeader.type, .type1)

    let messageHeaderType2 = MessageHeaderType2(timestampDelta: 1)
    let chunkHeader2 = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType2)

    XCTAssertEqual(chunkHeader2.basicHeader.type, .type2)
    
    let messageHeaderType3 = MessageHeaderType3()
    let chunkHeader3 = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType3)

    XCTAssertEqual(chunkHeader3.basicHeader.type, .type3)
  }
}
