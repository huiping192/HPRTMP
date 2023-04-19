import Foundation


actor WindowControl {
  
  let defaultWindowSize: Int64 = 250000
  
  var windowSize: Int64
  
  var totalInBytesCount: Int64 = 0
  var totalInBytesSeq: Int64 = 1

  var totalOutBytesCount: Int64 = 0
  var totalOutBytesSeq: Int64 = 1

  var inBytesWindowEvent: (Int64) -> Void

  init(inBytesWindowEvent: @escaping (Int64) -> Void) {
    self.windowSize = defaultWindowSize
    self.inBytesWindowEvent = inBytesWindowEvent
  }
  
  func addInBytesCount(_ count: Int64) {
    totalInBytesCount += count
    if totalInBytesCount >= windowSize * totalInBytesSeq {
      inBytesWindowEvent(totalInBytesCount)
      totalInBytesSeq += 1
    }
  }
  
  func addOutBytesCount(_ count: Int64) {
    totalOutBytesCount += count
    if totalOutBytesCount >= windowSize * totalOutBytesSeq {
      totalOutBytesSeq += 1
    }
  }
}
