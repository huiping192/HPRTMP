//
//  RTMPConnectionTests.swift
//
//
//  Created by Huiping Guo on 2026/02/26.
//

import XCTest
@testable import HPRTMP

final class RTMPConnectionTests: XCTestCase {

  /// Test that invalidate() can be called multiple times safely on a fresh connection.
  /// Verifies the guard condition (status == .none) prevents any crash or hang.
  func testMultipleInvalidateCalls() async throws {
    let connection = await RTMPConnection()

    await connection.invalidate()
    await connection.invalidate()
    await connection.invalidate()

    // No crash or hang = success
  }

  // Note: Full tests for continuation cleanup during active operations
  // require dependency injection of NetworkConnectable for proper mocking.
  // The fix ensures that:
  // 1. connectContinuation is resumed with connectionInvalidated error
  // 2. All streamCreationContinuations are resumed with connectionInvalidated error
  // 3. All continuations are cleared to prevent memory leaks
  //
  // This prevents infinite hangs and resource leaks when invalidate() is called
  // while establishConnection() or createStream() are waiting for server responses.
  // Follow-up: refactor RTMPConnection to accept NetworkConnectable via constructor injection.
}
