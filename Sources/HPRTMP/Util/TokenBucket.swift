
import Foundation

actor TokenBucket {
  private let defaultRate = 2500000  // 默认的补充速率
  private var tokens: Int  // 当前桶内的令牌数
  private var lastRefillTime: TimeInterval  // 上一次补充令牌的时间
  private var refillRate: Int  // 补充令牌的速率
  private var capacity: Int  // 桶的容量
  
  // 初始化函数，设置补充速率和容量，并将桶填满
  init() {
    self.refillRate = defaultRate
    self.capacity = defaultRate
    self.tokens = defaultRate
    self.lastRefillTime = Date().timeIntervalSince1970
  }
  
  func update(rate: Int, capacity: Int) {
    self.refillRate = rate
    self.capacity = capacity
    self.tokens = capacity
  }
  
  // 补充桶内的令牌
  func refill() {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = Int((currentTime - lastRefillTime) * 1000)
    let tokensToAdd = elapsedTime * refillRate / 1000  // 根据时间差和补充速率计算需要添加的令牌数
    tokens = min(tokens + tokensToAdd, capacity)  // 添加令牌但不超过桶的容量
    lastRefillTime = currentTime  // 更新最后补充时间
  }
  
  // 消费令牌并返回是否成功
  func consume(tokensNeeded: Int) -> Bool {
    refill()  // 先补充令牌
    if tokens >= tokensNeeded {  // 如果足够的令牌
      tokens -= tokensNeeded  // 消费令牌
      return true  // 返回成功
    }
    return false  // 不够令牌，返回失败
  }
}
