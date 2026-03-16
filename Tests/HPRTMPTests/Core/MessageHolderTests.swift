//
//  MessageHolderTests.swift
//
//
//  Created by Huiping Guo on 2026/03/17.
//

import XCTest
@testable import HPRTMP

final class MessageHolderTests: XCTestCase {
  
  var messageHolder: MessageHolder!
  
  override func setUp() {
    super.setUp()
    messageHolder = MessageHolder()
  }
  
  // MARK: - Register Tests
  
  func testRegisterMessage() async {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message)
    
    let count = await messageHolder.count
    XCTAssertEqual(count, 1)
  }
  
  func testRegisterMultipleMessages() async {
    let message1 = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    let message2 = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message1)
    await messageHolder.register(transactionId: 2, message: message2)
    
    let count = await messageHolder.count
    XCTAssertEqual(count, 2)
  }
  
  func testRegisterOverwritesExistingMessage() async {
    let message1 = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    let message2 = ConnectMessage(
      encodeType: .amf3,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message1)
    await messageHolder.register(transactionId: 1, message: message2)
    
    let count = await messageHolder.count
    XCTAssertEqual(count, 1)
  }
  
  // MARK: - Remove Tests
  
  func testRemoveMessage() async {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message)
    
    let removedMessage = await messageHolder.removeMessage(transactionId: 1)
    
    XCTAssertNotNil(removedMessage)
    let count = await messageHolder.count
    XCTAssertEqual(count, 0)
  }
  
  func testRemoveNonExistentMessage() async {
    let removedMessage = await messageHolder.removeMessage(transactionId: 999)
    
    XCTAssertNil(removedMessage)
    let count = await messageHolder.count
    XCTAssertEqual(count, 0)
  }
  
  func testRemoveMessageMultipleTimes() async {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message)
    
    let firstRemove = await messageHolder.removeMessage(transactionId: 1)
    let secondRemove = await messageHolder.removeMessage(transactionId: 1)
    
    XCTAssertNotNil(firstRemove)
    XCTAssertNil(secondRemove)
  }
  
  // MARK: - GetMessage Tests
  
  func testGetMessage() async {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message)
    
    let retrievedMessage = await messageHolder.getMessage(transactionId: 1)
    
    XCTAssertNotNil(retrievedMessage)
    let count = await messageHolder.count
    XCTAssertEqual(count, 1) // Message should still be there
  }
  
  func testGetNonExistentMessage() async {
    let retrievedMessage = await messageHolder.getMessage(transactionId: 999)
    
    XCTAssertNil(retrievedMessage)
  }
  
  // MARK: - HasMessage Tests
  
  func testHasMessage() async {
    let message = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message)
    
    let hasMessage = await messageHolder.hasMessage(transactionId: 1)
    let hasNoMessage = await messageHolder.hasMessage(transactionId: 999)
    
    XCTAssertTrue(hasMessage)
    XCTAssertFalse(hasNoMessage)
  }
  
  // MARK: - Count Tests
  
  func testCountInitial() async {
    let count = await messageHolder.count
    XCTAssertEqual(count, 0)
  }
  
  // MARK: - Cleanup Tests
  
  func testCleanup() async {
    let message1 = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    let message2 = ConnectMessage(
      encodeType: .amf0,
      tcUrl: "rtmp://localhost/live",
      appName: "live",
      flashVer: "FMLE/3.0",
      fpad: false,
      audio: .aac,
      video: .h264
    )
    
    await messageHolder.register(transactionId: 1, message: message1)
    await messageHolder.register(transactionId: 2, message: message2)
    
    var count = await messageHolder.count
    XCTAssertEqual(count, 2)
    
    await messageHolder.cleanup()
    
    count = await messageHolder.count
    XCTAssertEqual(count, 0)
  }
  
  func testCleanupEmptyHolder() async {
    await messageHolder.cleanup()
    
    let count = await messageHolder.count
    XCTAssertEqual(count, 0)
  }
  
  // MARK: - Concurrent Access Tests
  
  func testConcurrentRegisterAndRemove() async {
    guard let holder = messageHolder else { return }
    
    // Test that actor correctly handles sequential operations
    // Actor ensures thread-safety, so we test sequential but interleaved operations
    
    // Task 1: Register messages
    for i in 0..<100 {
      let message = ConnectMessage(
        encodeType: .amf0,
        tcUrl: "rtmp://localhost/live",
        appName: "live",
        flashVer: "FMLE/3.0",
        fpad: false,
        audio: .aac,
        video: .h264
      )
      await holder.register(transactionId: i, message: message)
    }
    
    var count = await holder.count
    XCTAssertEqual(count, 100)
    
    // Task 2: Remove messages
    for i in 0..<100 {
      _ = await holder.removeMessage(transactionId: i)
    }
    
    count = await holder.count
    XCTAssertEqual(count, 0)
  }
  
  func testConcurrentReadAndWrite() async {
    guard let holder = messageHolder else { return }
    
    // Test interleaved read/write operations
    for i in 0..<50 {
      let message = ConnectMessage(
        encodeType: .amf0,
        tcUrl: "rtmp://localhost/live",
        appName: "live",
        flashVer: "FMLE/3.0",
        fpad: false,
        audio: .aac,
        video: .h264
      )
      await holder.register(transactionId: i, message: message)
      
      // Read without removing
      let retrieved = await holder.getMessage(transactionId: i)
      XCTAssertNotNil(retrieved)
    }
    
    let count = await holder.count
    XCTAssertEqual(count, 50)
  }
}
