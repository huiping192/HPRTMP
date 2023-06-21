//
//  ChunkBasicTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/03.
//

import XCTest
@testable import HPRTMP

class BasicHeaderTests: XCTestCase {
  func testEncodeForStreamIdLessThanOrEqualTo63() {
    let header = BasicHeader(streamId: 63, type: .type0)
    let encodedData = header.encode()

    XCTAssertEqual(encodedData, Data([0 << 6 | 63]))
  }

  func testEncodeForStreamIdLessThanOrEqualTo319() {
    let header = BasicHeader(streamId: 319, type: .type1)
    let encodedData = header.encode()

    XCTAssertEqual(encodedData, Data([(1 << 6) | 0, 255]))
  }

  func testEncodeForStreamIdGreaterThan319() {
    let header = BasicHeader(streamId: 320, type: .type2)
    let encodedData = header.encode()

    let expectedData = Data([(2 << 6) | 0b00000001] + (UInt16(320 - 64)).bigEndian.data)
    XCTAssertEqual(encodedData, expectedData)
  }

  func testEncodeForDifferentTypes() {
    let header1 = BasicHeader(streamId: 319, type: .type0)
    let encodedData1 = header1.encode()

    XCTAssertEqual(encodedData1, Data([(0 << 6) | 0, 255]))

    let header2 = BasicHeader(streamId: 63, type: .type3)
    let encodedData2 = header2.encode()

    XCTAssertEqual(encodedData2, Data([(3 << 6) | 0b00111111]))
  }
}
