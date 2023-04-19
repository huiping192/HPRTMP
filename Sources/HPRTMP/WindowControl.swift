import Foundation


actor WindowControl {
  
  let defaultWindowSize: UInt32 = 250000
  
  var windowSize: UInt32
  
  var totalInBytesCount: UInt32 = 0
  var totalInBytesSeq: UInt32 = 1

  var totalOutBytesCount: UInt32 = 0
  var totalOutBytesSeq: UInt32 = 1

  var inBytesWindowEvent: ((UInt32) -> Void)? = nil

  func setInBytesWindowEvent(_ inBytesWindowEvent:((UInt32) -> Void)?) {
    self.inBytesWindowEvent = inBytesWindowEvent
  }
  
  func setWindowSize(_ size: UInt32) {
    self.windowSize = size
  }
  
  init() {
    self.windowSize = defaultWindowSize
  }
  
  func addInBytesCount(_ count: UInt32) {
    totalInBytesCount += count
    if totalInBytesCount >= windowSize * totalInBytesSeq {
      inBytesWindowEvent?(totalInBytesCount)
      totalInBytesSeq += 1
    }
  }
  
  func addOutBytesCount(_ count: UInt32) {
    totalOutBytesCount += count
    if totalOutBytesCount >= windowSize * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }
}
