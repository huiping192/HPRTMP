// cache the sent message for later handling by transaction ID
actor MessageHolder {
  private var messages = [Int: any RTMPMessage]()

  func register(transactionId: Int, message: any RTMPMessage) {
    messages[transactionId] = message
  }

  func removeMessage(transactionId: Int) -> (any RTMPMessage)? {
    messages.removeValue(forKey: transactionId)
  }

  func contains(transactionId: Int) -> Bool {
    messages[transactionId] != nil
  }

  var count: Int {
    messages.count
  }

  func clearAll() {
    messages.removeAll()
  }
}
