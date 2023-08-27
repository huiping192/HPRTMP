import Foundation

actor WindowControl {
  
  let defaultWindowSize: UInt32 = 250000
  
  var windowSize: UInt32
  
  var totalInBytesCount: UInt32 = 0
  var totalInBytesSeq: UInt32 = 1

  var totalOutBytesCount: UInt32 = 0
  var totalOutBytesSeq: UInt32 = 1

  var inBytesWindowEvent: ((UInt32) async -> Void)? = nil
  
  var receivedAcknowledgement: UInt32 = 0
  
  func setInBytesWindowEvent(_ inBytesWindowEvent:((UInt32) async -> Void)?) {
    self.inBytesWindowEvent = inBytesWindowEvent
  }
  
  func setWindowSize(_ size: UInt32) {
    self.windowSize = size
  }
  
  func updateReceivedAcknowledgement(_ size: UInt32) {
    receivedAcknowledgement = size
  }
  
  init() {
    self.windowSize = defaultWindowSize
  }
  
  func addInBytesCount(_ count: UInt32) async {
    totalInBytesCount += count
    if totalInBytesCount >= windowSize * totalInBytesSeq {
      await inBytesWindowEvent?(totalInBytesCount)
      totalInBytesSeq += 1
    }
  }
  
  func addOutBytesCount(_ count: UInt32) {
    totalOutBytesCount += count
    if totalOutBytesCount >= windowSize * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }
  
  var shouldWaitAcknowledgement: Bool {
    Int64(totalOutBytesCount) - Int64(receivedAcknowledgement) >= windowSize
  }
}
