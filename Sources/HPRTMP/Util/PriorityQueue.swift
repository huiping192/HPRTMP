import Foundation


enum MessagePriority {
  case high
  case medium
  case low
}

actor PriorityQueue {
  private var highPriorityQueue: [RTMPMessage] = []
  private var mediumPriorityQueue: [RTMPMessage] = []
  private var lowPriorityQueue: [RTMPMessage] = []
  
  func enqueue(_ message: RTMPMessage) {
    switch message.priority {
    case .high:
      highPriorityQueue.append(message)
    case .medium:
      mediumPriorityQueue.append(message)
    case .low:
      lowPriorityQueue.append(message)
    }
  }
  
  func dequeue() -> RTMPMessage? {
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
