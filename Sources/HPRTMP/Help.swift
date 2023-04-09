
actor MessageHolder {
  var raw = [Int: RTMPBaseMessage]()
  
  func register(transactionId: Int, message: RTMPBaseMessage) {
    raw[transactionId] = message
  }
  
  func removeMessage(transactionId: Int) -> RTMPBaseMessage? {
    let value = raw[transactionId]
    raw[transactionId] = nil
    return value
  }
}

actor TransactionIdGenerator {
  private var currentId: Int = 1
  
  func nextId() -> Int {
    currentId += 1
    return currentId
  }
}
