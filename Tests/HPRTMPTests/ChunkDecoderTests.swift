//
//  ChunkDecoderTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class ChunkDecoderTests: XCTestCase {
  
//  func testDecodeType0() {
//    let decoder = ChunkDecoder()
//    let expectedHeader = ChunkHeader(streamId: 2, messageHeader: MessageHeaderType0(timestamp: 5, messageLength: 20, type: .audio, messageStreamId: 0), chunkPayload: Data())
//    var decodedHeader: ChunkHeader?
//    decoder.chunkBlock = { header in
//      decodedHeader = header
//    }
//    decoder.decode(data: expectedHeader.encode(), chunk: nil)
//    XCTAssertEqual(decodedHeader, expectedHeader)
//  }
  
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
//    let decoder = ChunkDecoder()
//    let message = Data([0x80, 0x05, 0x00, 0x14, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00])
//    let expectedHeader = ChunkHeader(streamId: 2, header: MessageHeaderType0(timestamp: 5, messageLength: 20, type: .audio, messageStreamId: 0))
//    var decodedHeader: ChunkHeader?
//    decoder.chunkBlock = { header in
//      decodedHeader = header
//    }
//    decoder.decode(data: message, chunk: nil)
//    XCTAssertEqual(decodedHeader, expectedHeader)
//  }
//
//  func testDecodeType3() {
//    let decoder = ChunkDecoder()
//    let message = Data([0xC0, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
//    let expectedHeader = ChunkHeader(streamId: 2, header: MessageHeaderType3(timestamp: 0, messageLength: 0, type: .audio))
//    var decodedHeader: ChunkHeader?
//    decoder.chunkBlock = { header in
//      decodedHeader = header
//    }
//    decoder.decode(data: message, chunk: nil)
//    XCTAssertEqual(decodedHeader, expectedHeader)
//  }
//
}
