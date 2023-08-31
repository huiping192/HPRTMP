
import Foundation
actor TokenBucket {
  private let defaultRate = 2500000  // Default refill rate in tokens per second
  private var tokens: Int  // Current number of tokens in the bucket
  private var lastRefillTime: TimeInterval  // Last time the bucket was refilled
  private var refillRate: Int  // Rate at which tokens are refilled
  private var capacity: Int  // Maximum capacity of the bucket
  
  // Initialization, set the refill rate and capacity, and fill the bucket
  init() {
    self.refillRate = defaultRate
    self.capacity = defaultRate
    self.tokens = defaultRate
    self.lastRefillTime = Date().timeIntervalSince1970
  }
  
  // Update the rate and capacity of the bucket
  func update(rate: Int, capacity: Int) {
    self.refillRate = rate
    self.capacity = capacity
    self.tokens = capacity
  }
  
  // Refill tokens in the bucket
  func refill() {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = Int((currentTime - lastRefillTime) * 1000)
    let tokensToAdd = elapsedTime * refillRate / 1000  // Calculate tokens to add based on elapsed time and refill rate
    tokens = min(tokens + tokensToAdd, capacity)  // Add tokens but do not exceed maximum capacity
    lastRefillTime = currentTime  // Update the last refill time
  }
  
  // Consume tokens and return whether the operation was successful
  func consume(tokensNeeded: Int) -> Bool {
    refill()  // First, refill the bucket
    if tokens >= tokensNeeded {  // If there are enough tokens
      tokens -= tokensNeeded  // Consume the tokens
      return true  // Return success
    }
    return false  // Not enough tokens, return failure
  }
}
