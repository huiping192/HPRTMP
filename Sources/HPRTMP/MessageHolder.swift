// cache the sended message for late handling
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
