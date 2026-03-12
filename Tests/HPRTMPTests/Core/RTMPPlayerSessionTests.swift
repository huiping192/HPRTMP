//
//  RTMPPlayerSessionTests.swift
//  
//
//  Created by Huiping Guo on 2026/03/12.
//

import XCTest
@testable import HPRTMP

final class RTMPPlayerSessionTests: XCTestCase {
  
  func testPlayerSessionCanBeCreated() {
    // Verify RTMPPlayerSession can be instantiated
    let session = RTMPPlayerSession()
    XCTAssertNotNil(session)
  }
  
  func testStreamPropertiesAreAccessible() async {
    let session = RTMPPlayerSession()
    
    // Access streams - they are nonisolated(unsafe) so can be accessed
    XCTAssertNotNil(session.statusStream)
    XCTAssertNotNil(session.videoStream)
    XCTAssertNotNil(session.audioStream)
    XCTAssertNotNil(session.metaStream)
    XCTAssertNotNil(session.statisticsStream)
  }
  
  func testStopCanBeCalledOnNewSession() async {
    let session = RTMPPlayerSession()
    
    // Calling stop on a fresh session should not crash
    await session.stop()
    
    // If we reach here, stop completed successfully
    XCTAssertTrue(true)
  }
}
