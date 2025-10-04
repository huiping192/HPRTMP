import Foundation

/// Token bucket algorithm for rate limiting.
///
/// Tokens are continuously refilled at a specified rate. Operations consume tokens
/// and are allowed only when sufficient tokens are available.
actor TokenBucket {
  private let defaultRate = 2500000  // tokens per second

  private var tokens: Int
  private var lastRefillTime: TimeInterval
  private var refillRate: Int
  private var capacity: Int

  init() {
    self.refillRate = defaultRate
    self.capacity = defaultRate
    self.tokens = defaultRate
    self.lastRefillTime = Date().timeIntervalSince1970
  }

  /// Updates the refill rate and capacity, resetting tokens to capacity.
  func update(rate: Int, capacity: Int) {
    self.refillRate = rate
    self.capacity = capacity
    self.tokens = capacity
  }

  /// Refills tokens based on elapsed time since last refill.
  /// Formula: tokensToAdd = (elapsedSeconds * refillRate)
  private func refill() {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = Int((currentTime - lastRefillTime) * 1000)
    let tokensToAdd = elapsedTime * refillRate / 1000
    tokens = min(tokens + tokensToAdd, capacity)
    lastRefillTime = currentTime
  }

  /// Attempts to consume the specified number of tokens.
  /// - Returns: `true` if successful, `false` if insufficient tokens
  func consume(tokensNeeded: Int) -> Bool {
    refill()

    guard tokens >= tokensNeeded else {
      return false
    }

    tokens -= tokensNeeded
    return true
  }

  /// Calculates time (in nanoseconds) until the requested tokens become available.
  /// - Returns: 0 if tokens are already available, otherwise wait time capped at 1 second
  func timeUntilAvailable(tokensNeeded: Int) -> UInt64 {
    refill()

    guard tokens < tokensNeeded else {
      return 0
    }

    let tokensShortage = tokensNeeded - tokens
    let millisNeeded = (tokensShortage * 1000) / refillRate
    let cappedMillis = min(millisNeeded, 1000)  // Cap at 1s to avoid extremely long waits

    return UInt64(cappedMillis * 1_000_000)
  }
}
