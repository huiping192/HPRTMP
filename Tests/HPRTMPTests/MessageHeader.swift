//
//  MessageHeader.swift
//  
//
//  Created by Huiping Guo on 2023/02/05.
//

import XCTest
@testable import HPRTMP

class MessageHeaderType0Tests: XCTestCase {
  
  func testEncodeWithMaxTimestamp() {
    let header = MessageHeaderType0(timestamp: 16777215,
                                    messageLength: 5,
                                    type: .video,
                                    messageStreamId: 1)
    let expected = Data([0xff, 0xff, 0xff, 0x00, 0x00, 0x05, 0x09, 0x01, 0x00, 0x00, 0x00])
    XCTAssertEqual(header.encode(), expected)
  }
  
  func testEncodeWithExtendedTimestamp() {
    let header = MessageHeaderType0(timestamp: 16777216,
                                    messageLength: 5,
                                    type: .video,
                                    messageStreamId: 1)
    let expected = Data([0xff, 0xff, 0xff, 0x00, 0x00, 0x05, 0x09, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
    XCTAssertEqual(header.encode(), expected)
  }
  
  func testEncodeWithSmallTimestamp() {
    let header = MessageHeaderType0(timestamp: 1,
                                    messageLength: 5,
                                    type: .video,
                                    messageStreamId: 1)
    let expected = Data([0x00, 0x00, 0x01, 0x00, 0x00, 0x05, 0x09, 0x01, 0x00, 0x00, 0x00])
    
    
    
    
    XCTAssertEqual(header.encode(), expected)
  }
}

class MessageHeaderType1Tests: XCTestCase {
  func testEncode() {
    let header = MessageHeaderType1(timestampDelta: 100, messageLength: 100, type: .audio)
    let expectedData = Data([0x00, 0x00, 0x64, 0x00, 0x00, 0x64, 0x08])
    XCTAssertEqual(header.encode(), expectedData)
  }
}
