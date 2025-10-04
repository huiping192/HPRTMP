
import XCTest
@testable import HPRTMP

class TokenBucketTests: XCTestCase {
    
    func testTokenBucket() async {
        let tokenBucket = TokenBucket()
        
        // Update rate and capacity for testing (optional)
        await tokenBucket.update(rate: 2500000, capacity: 2500000)
        
        // Test 1: Send packets at a permissible rate
        var successCount = 0
        for _ in 1...5 {
            if await tokenBucket.consume(tokensNeeded: 500000) {
                successCount += 1
            }
          try? await Task.sleep(nanoseconds: 200 * 1_000_000) // Sleep for 200ms
        }
        XCTAssertEqual(successCount, 5, "Failed to send packets at permissible rate")
        
        // Test 2: Send packets at an exceeding rate
        successCount = 0
        for _ in 1...5 {
            if await tokenBucket.consume(tokensNeeded: 1000000) {
                successCount += 1
            }
          try? await Task.sleep(nanoseconds: 100 * 1_000_000) // Sleep for 100ms
        }
        XCTAssertLessThan(successCount, 5, "Should not be able to send all packets at exceeding rate")
    }
}
