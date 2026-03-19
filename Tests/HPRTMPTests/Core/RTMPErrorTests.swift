//
//  RTMPErrorTests.swift
//
//
//  Created by Huiping Guo on 2026/02/26.
//

import XCTest
@testable import HPRTMP

final class RTMPErrorTests: XCTestCase {
  
  // MARK: - LocalizedError Conformance Tests
  
  func testHandshakeErrorDescription() {
    let error = RTMPError.handShake(desc: "Handshake failed")
    XCTAssertEqual(error.errorDescription, "Handshake failed")
    XCTAssertEqual(error.localizedDescription, "Handshake failed")
  }
  
  func testStreamErrorDescription() {
    let error = RTMPError.stream(desc: "Stream error occurred")
    XCTAssertEqual(error.errorDescription, "Stream error occurred")
    XCTAssertEqual(error.localizedDescription, "Stream error occurred")
  }
  
  func testCommandErrorDescription() {
    let error = RTMPError.command(desc: "Command failed")
    XCTAssertEqual(error.errorDescription, "Command failed")
    XCTAssertEqual(error.localizedDescription, "Command failed")
  }
  
  func testUnknownErrorDescription() {
    let error = RTMPError.unknown(desc: "Unknown error")
    XCTAssertEqual(error.errorDescription, "Unknown error")
    XCTAssertEqual(error.localizedDescription, "Unknown error")
  }
  
  func testConnectionNotEstablishedDescription() {
    let error = RTMPError.connectionNotEstablished
    XCTAssertEqual(error.errorDescription, "Connection not established")
    XCTAssertEqual(error.localizedDescription, "Connection not established")
  }
  
  func testConnectionInvalidatedDescription() {
    let error = RTMPError.connectionInvalidated
    XCTAssertEqual(error.errorDescription, "Connection invalidated")
    XCTAssertEqual(error.localizedDescription, "Connection invalidated")
  }
  
  func testDataRetrievalFailedDescription() {
    let error = RTMPError.dataRetrievalFailed
    XCTAssertEqual(error.errorDescription, "Data retrieval failed unexpectedly")
    XCTAssertEqual(error.localizedDescription, "Data retrieval failed unexpectedly")
  }
  
  func testBufferOverflowDescription() {
    let error = RTMPError.bufferOverflow
    XCTAssertEqual(error.errorDescription, "Buffer overflow: received data exceeds maximum allowed size")
    XCTAssertEqual(error.localizedDescription, "Buffer overflow: received data exceeds maximum allowed size")
  }
  
  func testInvalidChunkSizeDescription() {
    let error = RTMPError.invalidChunkSize(size: 100, min: 128, max: 16384)
    XCTAssertEqual(error.errorDescription, "Invalid chunk size: 100. Must be between 128 and 16384")
    XCTAssertEqual(error.localizedDescription, "Invalid chunk size: 100. Must be between 128 and 16384")
  }
  
  // MARK: - Equatable Tests
  
  func testHandshakeErrorEquality() {
    let error1 = RTMPError.handShake(desc: "Same error")
    let error2 = RTMPError.handShake(desc: "Same error")
    let error3 = RTMPError.handShake(desc: "Different error")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testConnectionErrorsEquality() {
    let error1 = RTMPError.connectionNotEstablished
    let error2 = RTMPError.connectionNotEstablished
    let error3 = RTMPError.connectionInvalidated
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testInvalidChunkSizeEquality() {
    let error1 = RTMPError.invalidChunkSize(size: 100, min: 128, max: 16384)
    let error2 = RTMPError.invalidChunkSize(size: 100, min: 128, max: 16384)
    let error3 = RTMPError.invalidChunkSize(size: 200, min: 128, max: 16384)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  func testDifferentErrorTypesNotEqual() {
    let handshake = RTMPError.handShake(desc: "Error")
    let stream = RTMPError.stream(desc: "Error")
    let connection = RTMPError.connectionNotEstablished
    
    XCTAssertNotEqual(handshake, stream)
    XCTAssertNotEqual(handshake, connection)
    XCTAssertNotEqual(stream, connection)
  }
  
  // MARK: - Sendable Conformance Test
  
  func testSendableConformance() async {
    // Test that RTMPError can be safely sent across actor boundaries
    let error = RTMPError.connectionNotEstablished
    
    await Task {
      // This compiles and runs without warnings because RTMPError is Sendable
      let capturedError = error
      XCTAssertEqual(capturedError, RTMPError.connectionNotEstablished)
    }.value
  }
  
  func testSendableWithAssociatedValues() async {
    let error = RTMPError.invalidChunkSize(size: 100, min: 128, max: 16384)
    
    await Task {
      let capturedError = error
      XCTAssertEqual(capturedError, error)
    }.value
  }
  
  // MARK: - Error Casting Tests
  
  func testErrorCasting() {
    let rtmpError: RTMPError = .connectionNotEstablished
    let error: Error = rtmpError
    
    // Test that we can cast back to RTMPError
    XCTAssertTrue(error is RTMPError)
    
    if let castError = error as? RTMPError {
      XCTAssertEqual(castError, .connectionNotEstablished)
    } else {
      XCTFail("Failed to cast Error to RTMPError")
    }
  }
  
  func testLocalizedErrorCasting() {
    let rtmpError: RTMPError = .bufferOverflow
    let error: Error = rtmpError
    
    // Test that we can cast to LocalizedError
    XCTAssertTrue(error is LocalizedError)
    
    if let localizedError = error as? LocalizedError {
      XCTAssertEqual(localizedError.errorDescription, "Buffer overflow: received data exceeds maximum allowed size")
    } else {
      XCTFail("Failed to cast Error to LocalizedError")
    }
  }
}
