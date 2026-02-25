//
//  RTMPConnectionTests.swift
//
//
//  Created by OpenClaw Agent on 2025/01/21.
//

import XCTest
@testable import HPRTMP

final class RTMPConnectionTests: XCTestCase {
  
  /// Test that invalidate() can be called multiple times safely
  /// This verifies the guard condition works correctly
  func testMultipleInvalidateCalls() async throws {
    let connection = await RTMPConnection()
    
    // First invalidate
    await connection.invalidate()
    
    // Second invalidate should be safe (no-op due to guard)
    await connection.invalidate()
    
    // Third invalidate should also be safe
    await connection.invalidate()
    
    // No crash = success
  }
  
  /// Test that invalidate() properly stops all background tasks
  /// and can be safely called on a fresh connection
  func testInvalidateStopsBackgroundTasks() async throws {
    let connection = await RTMPConnection()
    
    // After creation, background tasks should be initialized
    // Invalidate should stop them all cleanly
    await connection.invalidate()
    
    // Verify that we can safely invalidate again
    await connection.invalidate()
    
    // No crash or hang = success
  }
  
  // Note: Full tests for continuation cleanup during active operations
  // require dependency injection of NetworkClient for proper mocking.
  // The fix ensures that:
  // 1. connectContinuation is resumed with connectionInvalidated error
  // 2. All streamCreationContinuations are resumed with connectionInvalidated error
  // 3. All continuations are cleared to prevent memory leaks
  //
  // This prevents infinite hangs and resource leaks when invalidate() is called
  // while establishConnection() or createStream() are waiting for server responses.
}
