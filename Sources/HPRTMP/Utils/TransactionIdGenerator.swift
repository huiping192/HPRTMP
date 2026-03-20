
// generator transactionId
actor TransactionIdGenerator {
  private var currentId: Int = 0
  
  func nextId() -> Int {
    currentId += 1
    return currentId
  }
}
