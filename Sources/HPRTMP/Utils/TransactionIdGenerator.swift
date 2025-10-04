
// generator transactionId
actor TransactionIdGenerator {
  private var currentId: Int = 1
  
  func nextId() -> Int {
    currentId += 1
    return currentId
  }
}
