import Foundation

// WindowControl actor manages the flow control in RTMP communication
actor WindowControl {
    
  // The window size for flow control, usually set by a peer. default: 2.4mb
  private(set) var windowSize: UInt32 = 2500000
  
  // Total number of incoming bytes, updated as data is received.
  private(set) var totalInBytesCount: UInt32 = 0
  // Sequence number for tracking incoming bytes, incremented after each window.
  private(set) var totalInBytesSeq: UInt32 = 1

  // Total number of outgoing bytes, updated as data is sent.
  private(set) var totalOutBytesCount: UInt32 = 0
  // Sequence number for tracking outgoing bytes, incremented after each window.
  private(set) var totalOutBytesSeq: UInt32 = 1

  // Callback function triggered when incoming bytes reach the window limit.
  private(set) var inBytesWindowEvent: ((UInt32) async -> Void)? = nil
  
  // The last byte count acknowledged by a peer.
  private(set) var receivedAcknowledgement: UInt32 = 0
  
  // Sets the callback function for incoming byte window events.
  func setInBytesWindowEvent(_ inBytesWindowEvent:((UInt32) async -> Void)?) {
    self.inBytesWindowEvent = inBytesWindowEvent
  }
  
  // Sets the window size for flow control, usually updated from a peer.
  func setWindowSize(_ size: UInt32) {
    self.windowSize = size
  }
  
  // Updates the last acknowledged byte count, usually set by a peer.
  func updateReceivedAcknowledgement(_ size: UInt32) {
    receivedAcknowledgement = size
  }
  
  // Adds to the total count of incoming bytes and triggers the window event if necessary.
  func addInBytesCount(_ count: UInt32) async {
    totalInBytesCount += count
    if totalInBytesCount >= windowSize * totalInBytesSeq {
      await inBytesWindowEvent?(totalInBytesCount)
      totalInBytesSeq += 1
    }
  }
  
  // Adds to the total count of outgoing bytes and updates the sequence number if necessary.
  func addOutBytesCount(_ count: UInt32) {
    totalOutBytesCount += count
    if totalOutBytesCount >= windowSize * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }
  
  // Determines whether the actor should wait for an acknowledgement from a peer.
  var shouldWaitAcknowledgement: Bool {
    Int64(totalOutBytesCount) - Int64(receivedAcknowledgement) >= windowSize
  }
}
