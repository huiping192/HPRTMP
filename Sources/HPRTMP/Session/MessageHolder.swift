// cache the sended message for late handling
actor MessageHolder {
  /// Pending messages indexed by transaction ID
  private var pendingMessages = [Int: any RTMPMessage]()

  /// Register a message with a transaction ID for later response handling
  /// - Parameters:
  ///   - transactionId: The transaction ID to associate with the message
  ///   - message: The RTMP message to store
  func register(transactionId: Int, message: any RTMPMessage) {
    pendingMessages[transactionId] = message
  }

  /// Retrieve and remove a message by transaction ID
  /// - Parameter transactionId: The transaction ID to look up
  /// - Returns: The associated message if found, nil otherwise
  func removeMessage(transactionId: Int) -> (any RTMPMessage)? {
    pendingMessages.removeValue(forKey: transactionId)
  }

  /// Get a message by transaction ID without removing it
  /// - Parameter transactionId: The transaction ID to look up
  /// - Returns: The associated message if found, nil otherwise
  func getMessage(transactionId: Int) -> (any RTMPMessage)? {
    pendingMessages[transactionId]
  }

  /// Get the number of pending messages
  var count: Int {
    pendingMessages.count
  }

  /// Check if a message exists for the given transaction ID
  /// - Parameter transactionId: The transaction ID to check
  /// - Returns: true if a message exists for the transaction ID
  func hasMessage(transactionId: Int) -> Bool {
    pendingMessages[transactionId] != nil
  }

  /// Remove all pending messages
  func cleanup() {
    pendingMessages.removeAll()
  }
}
