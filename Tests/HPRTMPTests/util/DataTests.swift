//
//  DataTests.swift
//  
//
//  Created by Huiping Guo on 2023/02/03.
//

import XCTest

@testable import HPRTMP

class DataTests: XCTestCase {
  func testSplit() {
    // Given
    let data = Data("0123456789".utf8)
    
    // When
    let result = data.split(size: 2)
    
    // Then
    XCTAssertEqual(result.count, 5)
    XCTAssertEqual(result[0], Data("01".utf8))
    XCTAssertEqual(result[1], Data("23".utf8))
    XCTAssertEqual(result[2], Data("45".utf8))
    XCTAssertEqual(result[3], Data("67".utf8))
    XCTAssertEqual(result[4], Data("89".utf8))
  }
  
  func testSplitWithRemainder() {
    // Given
    let data = Data("0123456789".utf8)
    
    // When
    let result = data.split(size: 3)
    
    // Then
    XCTAssertEqual(result.count, 4)
    XCTAssertEqual(result[0], Data("012".utf8))
    XCTAssertEqual(result[1], Data("345".utf8))
    XCTAssertEqual(result[2], Data("678".utf8))
    XCTAssertEqual(result[3], Data("9".utf8))
  }
  
  func testSplitWithSizeGreaterThanDataCount() {
    // Given
    let data = Data("0123456789".utf8)
    
    // When
    let result = data.split(size: 20)
    
    // Then
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0], data)
  }
  
  func testSplitWithSizeZero() {
    // Given
    let data = Data("0123456789".utf8)
    
    // When
    let result = data.split(size: 0)
    
    // Then
    XCTAssertEqual(result.count, 0)
  }
}
