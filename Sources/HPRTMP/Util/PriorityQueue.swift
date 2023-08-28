import Foundation


enum MessagePriority {
  case high
  case medium
  case low
}

actor PriorityQueue {
  private var highPriorityQueue: [(RTMPMessage,Bool)] = []
  private var mediumPriorityQueue: [(RTMPMessage,Bool)] = []
  private var lowPriorityQueue: [(RTMPMessage,Bool)] = []
  
  func enqueue(_ message: RTMPMessage, firstType: Bool) {
    switch message.priority {
    case .high:
      highPriorityQueue.append((message,firstType))
    case .medium:
      mediumPriorityQueue.append((message,firstType))
    case .low:
      lowPriorityQueue.append((message,firstType))
    }
  }
  
  func dequeue() -> (RTMPMessage,Bool)? {
    if !highPriorityQueue.isEmpty {
      return highPriorityQueue.removeFirst()
    } else if !mediumPriorityQueue.isEmpty {
      return mediumPriorityQueue.removeFirst()
    } else if !lowPriorityQueue.isEmpty {
      return lowPriorityQueue.removeFirst()
    } else {
      return nil
    }
  }
  
  var isEmpty: Bool {
    highPriorityQueue.isEmpty && mediumPriorityQueue.isEmpty && lowPriorityQueue.isEmpty
  }
}
