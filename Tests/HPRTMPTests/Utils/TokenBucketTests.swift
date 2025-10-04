
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

    func testTimeUntilAvailable_withEnoughTokens() async {
        let tokenBucket = TokenBucket()
        await tokenBucket.update(rate: 2500000, capacity: 2500000)

        // Should return 0 when enough tokens are available
        let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: 1000000)
        XCTAssertEqual(waitTime, 0, "Should return 0 when enough tokens are available")
    }

    func testTimeUntilAvailable_withInsufficientTokens() async {
        let tokenBucket = TokenBucket()
        await tokenBucket.update(rate: 2500000, capacity: 2500000)

        // Consume all tokens
        _ = await tokenBucket.consume(tokensNeeded: 2500000)

        // Request more tokens than can be refilled in a few milliseconds
        // Even if 5ms passes (12500 tokens refilled), we still need to wait
        let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: 100000)

        // Should be non-zero since we need significant tokens
        // Time needed = (100000 * 1000) / 2500000 = 40ms = 40000000ns
        XCTAssertGreaterThan(waitTime, 0, "Should return non-zero wait time when tokens are insufficient")
        XCTAssertLessThanOrEqual(waitTime, 50_000_000, "Wait time should be reasonable (< 50ms)")
    }

    func testTimeUntilAvailable_cappedAtOneSecond() async {
        let tokenBucket = TokenBucket()
        await tokenBucket.update(rate: 1000, capacity: 1000)  // Very slow refill rate

        // Consume all tokens
        _ = await tokenBucket.consume(tokensNeeded: 1000)

        // Request a huge amount of tokens that would take > 1 second
        let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: 100000)

        // Should be capped at 1 second (1000ms = 1000000000ns)
        XCTAssertEqual(waitTime, 1000_000_000, "Wait time should be capped at 1 second")
    }

    func testTimeUntilAvailable_precisionTest() async {
        let tokenBucket = TokenBucket()
        await tokenBucket.update(rate: 2500000, capacity: 2500000)

        // Consume most tokens, leaving some available
        _ = await tokenBucket.consume(tokensNeeded: 2400000)

        // Need 100000 tokens, have 100000, should return 0
        let waitTime1 = await tokenBucket.timeUntilAvailable(tokensNeeded: 100000)
        XCTAssertEqual(waitTime1, 0, "Should return 0 when exactly enough tokens")

        // Need 200000 tokens, have ~100000 (accounting for small refill), need to wait
        // Time = (100000 * 1000) / 2500000 = 40ms = 40000000ns
        let waitTime2 = await tokenBucket.timeUntilAvailable(tokensNeeded: 200000)
        XCTAssertGreaterThan(waitTime2, 0, "Should return wait time when tokens are insufficient")
        XCTAssertLessThanOrEqual(waitTime2, 50_000_000, "Wait time should be < 50ms")
    }

    func testTimeUntilAvailable_withRefill() async {
        let tokenBucket = TokenBucket()
        await tokenBucket.update(rate: 2500000, capacity: 2500000)

        // Consume all tokens
        _ = await tokenBucket.consume(tokensNeeded: 2500000)

        // Wait a bit for refill
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // After 100ms, should have refilled ~250000 tokens (2500000 * 0.1)
        // Asking for 200000 should return 0 or very small wait time
        let waitTime = await tokenBucket.timeUntilAvailable(tokensNeeded: 200000)

        // Should be 0 or very small since tokens have been refilled
        XCTAssertLessThanOrEqual(waitTime, 10_000_000, "Wait time should be small after refill (< 10ms)")
    }
}
