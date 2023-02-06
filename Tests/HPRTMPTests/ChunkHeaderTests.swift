//
//  ChunkHeaderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/06.
//

import XCTest
@testable import HPRTMP

final class ChunkHeaderTests: XCTestCase {

  func testEncode() {
    let streamId = 1
    let messageHeader = MessageHeaderType0(timestamp: 1, messageLength: 1, type: .video, messageStreamId: streamId)
    let chunkPayload = Data([0x00, 0x01, 0x02, 0x03])
    let chunkHeader = ChunkHeader(streamId: streamId, messageHeader: messageHeader, chunkPayload: chunkPayload)

    let encodedData = chunkHeader.encode()

    let basicHeader = BasicHeader(streamId: UInt16(streamId), type: .type0)
    let expectedData = basicHeader.encode() + messageHeader.encode() + chunkPayload
    XCTAssertEqual(encodedData, expectedData)
  }

  func testBasicHeaderType() {
    let streamId = 2
    let messageHeaderType1 = MessageHeaderType1(timestampDelta: 1, messageLength: 1, type: .audio)
    let chunkPayload = Data([0x00, 0x01, 0x02, 0x03])
    let chunkHeader = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType1, chunkPayload: chunkPayload)

    XCTAssertEqual(chunkHeader.basicHeader.type, .type1)

    let messageHeaderType2 = MessageHeaderType2(timestampDelta: 1)
    let chunkHeader2 = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType2, chunkPayload: chunkPayload)

    XCTAssertEqual(chunkHeader2.basicHeader.type, .type2)
    
    let messageHeaderType3 = MessageHeaderType3()
    let chunkHeader3 = ChunkHeader(streamId: streamId, messageHeader: messageHeaderType3, chunkPayload: chunkPayload)

    XCTAssertEqual(chunkHeader3.basicHeader.type, .type3)
  }
}
