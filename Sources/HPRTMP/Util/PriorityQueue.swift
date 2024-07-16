import Foundation


enum MessagePriority {
  case high
  case medium
  case low
}

actor PriorityQueue {
  
  struct MessageContainer {
    let message: RTMPMessage
    let isFirstType: Bool
  }
  
  private var highPriorityQueue: [MessageContainer] = []
  private var mediumPriorityQueue: [MessageContainer] = []
  private var lowPriorityQueue: [MessageContainer] = []
  private var waitMessageContinuation: CheckedContinuation<Void, Never>? = nil
  
  func enqueue(_ message: RTMPMessage, firstType: Bool) {
    let container = MessageContainer(message: message, isFirstType: firstType)
    switch message.priority {
    case .high:
      highPriorityQueue.append(container)
    case .medium:
      mediumPriorityQueue.append(container)
    case .low:
      lowPriorityQueue.append(container)
    }
    
    waitMessageContinuation?.resume()
    waitMessageContinuation = nil
  }
  
  func dequeue() async -> MessageContainer? {
    while !Task.isCancelled {
      if !highPriorityQueue.isEmpty {
        return highPriorityQueue.removeFirst()
      } else if !mediumPriorityQueue.isEmpty {
        return mediumPriorityQueue.removeFirst()
      } else if !lowPriorityQueue.isEmpty {
        return lowPriorityQueue.removeFirst()
      } else {
        await withTaskCancellationHandler {
          await withCheckedContinuation { cont in
            self.waitMessageContinuation = cont
          }
        } onCancel: {
        }
      }
    }
    return nil
  }
  
  var isEmpty: Bool {
    highPriorityQueue.isEmpty && mediumPriorityQueue.isEmpty && lowPriorityQueue.isEmpty
  }
  
  var pendingMessageCount: Int {
    highPriorityQueue.count + mediumPriorityQueue.count + lowPriorityQueue.count
  }
}
