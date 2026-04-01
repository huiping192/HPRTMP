//
//  TypeSafeIdentifiersTests.swift
//  HPRTMPTests
//
//  Tests for type-safe identifiers
//

import XCTest
@testable import HPRTMP

final class TypeSafeIdentifiersTests: XCTestCase {

  // MARK: - MessageStreamId Tests

  func testMessageStreamIdInitialization() {
    let streamId = MessageStreamId(1)
    XCTAssertEqual(streamId.value, 1)
  }

  func testMessageStreamIdZero() {
    XCTAssertEqual(MessageStreamId.zero.value, 0)
  }

  func testMessageStreamIdEquality() {
    let id1 = MessageStreamId(1)
    let id2 = MessageStreamId(1)
    let id3 = MessageStreamId(2)
    XCTAssertEqual(id1, id2)
    XCTAssertNotEqual(id1, id3)
  }

  func testMessageStreamIdHashable() {
    let id1 = MessageStreamId(1)
    let id2 = MessageStreamId(1)
    XCTAssertEqual(id1.hashValue, id2.hashValue)
  }

  func testMessageStreamIdDescription() {
    let streamId = MessageStreamId(5)
    XCTAssertEqual(streamId.description, "MessageStreamId(5)")
  }

  // MARK: - ChunkStreamId Tests

  func testChunkStreamIdInitialization() {
    let chunkId = ChunkStreamId(1)
    XCTAssertEqual(chunkId.value, 1)
  }

  func testChunkStreamIdZero() {
    XCTAssertEqual(ChunkStreamId.zero.value, 0)
  }

  func testChunkStreamIdEquality() {
    let id1 = ChunkStreamId(1)
    let id2 = ChunkStreamId(1)
    let id3 = ChunkStreamId(2)
    XCTAssertEqual(id1, id2)
    XCTAssertNotEqual(id1, id3)
  }

  func testChunkStreamIdDescription() {
    let chunkId = ChunkStreamId(3)
    XCTAssertEqual(chunkId.description, "ChunkStreamId(3)")
  }

  // MARK: - Timestamp Tests

  func testTimestampInitialization() {
    let timestamp = Timestamp(1000)
    XCTAssertEqual(timestamp.value, 1000)
  }

  func testTimestampZero() {
    XCTAssertEqual(Timestamp.zero.value, 0)
  }

  func testTimestampMax() {
    XCTAssertEqual(Timestamp.max.value, 16777215) // 0xFFFFFF
  }

  func testTimestampDescription() {
    let timestamp = Timestamp(1500)
    XCTAssertEqual(timestamp.description, "1500ms")
  }

  func testTimestampAddition() {
    let t1 = Timestamp(1000)
    let t2 = Timestamp(500)
    let result = t1 + t2
    XCTAssertEqual(result.value, 1500)
  }

  func testTimestampAdditionOverflow() {
    // Test saturating addition - max UInt32 + 1 should wrap to 1
    let t1 = Timestamp(UInt32.max)
    let t2 = Timestamp(1)
    let result = t1 + t2
    // &+ wraps around: UInt32.max + 1 = 0
    XCTAssertEqual(result.value, 0)
  }

  func testTimestampSubtraction() {
    let t1 = Timestamp(1500)
    let t2 = Timestamp(500)
    let result = t1 - t2
    XCTAssertEqual(result.value, 1000)
  }

  func testTimestampSubtractionUnderflow() {
    // Test saturating subtraction - smaller - larger should wrap
    let t1 = Timestamp(500)
    let t2 = Timestamp(1000)
    let result = t1 - t2
    // &- wraps around: 500 - 1000 = UInt32.max - 499
    XCTAssertEqual(result.value, UInt32(500) &- UInt32(1000))
  }

  func testTimestampCompoundAddition() {
    var timestamp = Timestamp(1000)
    timestamp += Timestamp(500)
    XCTAssertEqual(timestamp.value, 1500)
  }

  func testTimestampComparison() {
    let t1 = Timestamp(500)
    let t2 = Timestamp(1000)
    let t3 = Timestamp(500)
    XCTAssertTrue(t1 < t2)
    XCTAssertFalse(t2 < t1)
    XCTAssertFalse(t1 < t3)
  }

  func testTimestampEquality() {
    let t1 = Timestamp(1000)
    let t2 = Timestamp(1000)
    let t3 = Timestamp(2000)
    XCTAssertEqual(t1, t2)
    XCTAssertNotEqual(t1, t3)
  }

  func testTimestampInitClamping() {
    // Test clamping from UInt64
    let t1 = Timestamp(clamping: 100)
    XCTAssertEqual(t1.value, 100)

    // Test clamping from large UInt64 (larger than UInt32.max)
    let largeValue: UInt64 = UInt64(UInt32.max) + 100
    let t2 = Timestamp(clamping: largeValue)
    XCTAssertEqual(t2.value, UInt32.max)
  }

  func testTimestampInitSaturating() {
    // Test saturating from positive Int
    let t1 = Timestamp(saturating: 100)
    XCTAssertEqual(t1.value, 100)

    // Test saturating from negative Int (should become 0)
    let t2 = Timestamp(saturating: -10)
    XCTAssertEqual(t2.value, 0)

    // Test saturating from large Int (should clamp to UInt32.max)
    let largeValue = Int(UInt32.max) + 100
    let t3 = Timestamp(saturating: largeValue)
    XCTAssertEqual(t3.value, UInt32.max)
  }

  func testTimestampHashable() {
    let t1 = Timestamp(1000)
    let t2 = Timestamp(1000)
    XCTAssertEqual(t1.hashValue, t2.hashValue)
  }
}
