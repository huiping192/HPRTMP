//
//  TransactionIdGeneratorTests.swift
//  HPRTMPTests
//
//  Created by Huiping Guo on 2026/03/20.
//

import XCTest
@testable import HPRTMP

final class TransactionIdGeneratorTests: XCTestCase {

  func testNextIdStartsFromOne() async {
    let generator = TransactionIdGenerator()
    let firstId = await generator.nextId()
    XCTAssertEqual(firstId, 1, "First transaction ID should be 1")
  }

  func testNextIdIncrementsSequentially() async {
    let generator = TransactionIdGenerator()

    let firstId = await generator.nextId()
    let secondId = await generator.nextId()
    let thirdId = await generator.nextId()

    XCTAssertEqual(firstId, 1)
    XCTAssertEqual(secondId, 2)
    XCTAssertEqual(thirdId, 3)
  }

  func testMultipleInstancesIndependent() async {
    let generator1 = TransactionIdGenerator()
    let generator2 = TransactionIdGenerator()

    let id1 = await generator1.nextId()
    let id2 = await generator2.nextId()

    // Both should return 1 since they're independent instances
    XCTAssertEqual(id1, 1)
    XCTAssertEqual(id2, 1)
  }
}
