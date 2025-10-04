// cache the sended message for late handling
actor MessageHolder {
  var raw = [Int: any RTMPMessage]()

  func register(transactionId: Int, message: any RTMPMessage) {
    raw[transactionId] = message
  }

  func removeMessage(transactionId: Int) -> (any RTMPMessage)? {
    let value = raw[transactionId]
    raw[transactionId] = nil
    return value
  }
}
