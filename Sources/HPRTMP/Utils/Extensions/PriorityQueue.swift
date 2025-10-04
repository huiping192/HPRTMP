import Foundation


public enum MessagePriority {
  case high
  case medium
  case low
}

actor MessagePriorityQueue {
  
  struct MessageContainer {
    let message: RTMPMessage
    let isFirstType: Bool
    var continuation: CheckedContinuation<Void, Never>?
  }
  
  private var highPriorityQueue: [MessageContainer] = []
  private var mediumPriorityQueue: [MessageContainer] = []
  private var lowPriorityQueue: [MessageContainer] = []
  private var waitMessageContinuation: CheckedContinuation<Void, Never>? = nil
  
  func enqueue(_ message: RTMPMessage, firstType: Bool, continuation: CheckedContinuation<Void, Never>? = nil) {
    let container = MessageContainer(message: message, isFirstType: firstType, continuation: continuation)
    switch message.priority {
    case .high:
      highPriorityQueue.append(container)
    case .medium:
      mediumPriorityQueue.append(container)
    case .low:
      lowPriorityQueue.append(container)
    }

    resumeWaitContinuationIfNeeded()
  }
  
  func dequeue() async -> MessageContainer? {
    while !Task.isCancelled {
      if !highPriorityQueue.isEmpty {
        return highPriorityQueue.removeFirst()
      }
      
      if !mediumPriorityQueue.isEmpty {
        return mediumPriorityQueue.removeFirst()
      }
      
      if !lowPriorityQueue.isEmpty {
        return lowPriorityQueue.removeFirst()
      }

      await withTaskCancellationHandler {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
          self.waitMessageContinuation = cont
        }
      } onCancel: {
        Task { [weak self] in
          await self?.resumeWaitContinuationIfNeeded()
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

  private func resumeWaitContinuationIfNeeded() {
    guard let waitMessageContinuation else { return }
    waitMessageContinuation.resume()
    self.waitMessageContinuation = nil
  }

  // Requeues a message to the front of its priority queue (used when waiting for ACK)
  func requeue(_ container: MessageContainer) {
    switch container.message.priority {
    case .high:
      highPriorityQueue.insert(container, at: 0)
    case .medium:
      mediumPriorityQueue.insert(container, at: 0)
    case .low:
      lowPriorityQueue.insert(container, at: 0)
    }
  }
}
