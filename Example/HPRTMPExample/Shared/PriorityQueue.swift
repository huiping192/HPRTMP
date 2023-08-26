//
//  PriorityQueue.swift
//  HPRTMPExample
//
//  Created by 郭 輝平 on 2023/08/26.
//

import Foundation

actor PriorityQueue {
  private var heap: [Frame] = []
  
  var isEmpty: Bool {
    heap.isEmpty
  }
  
  var count: Int {
    heap.count
  }
  
  func peek() -> Frame? {
    heap.first
  }
  
  func enqueue(_ element: Frame) {
    heap.append(element)
    siftUp(heap.count - 1)
  }
  
  func dequeue() -> Frame? {
    if heap.isEmpty {
      return nil
    } else if heap.count == 1 {
      return heap.removeFirst()
    } else {
      heap.swapAt(0, heap.count - 1)
      let element = heap.removeLast()
      siftDown(0)
      return element
    }
  }
  
  func clear() {
    heap.removeAll()
  }
  
  
  
  private func siftUp(_ index: Int) {
    let parent = (index - 1) / 2
    if index > 0, heap[parent].ts > heap[index].ts {
      heap.swapAt(parent, index)
      siftUp(parent)
    }
  }
  
  private func siftDown(_ index: Int) {
    let left = index * 2 + 1
    let right = index * 2 + 2
    var minIndex = index
    
    if left < heap.count, heap[left].ts < heap[minIndex].ts {
      minIndex = left
    }
    
    if right < heap.count, heap[right].ts < heap[minIndex].ts {
      minIndex = right
    }
    
    if minIndex != index {
      heap.swapAt(index, minIndex)
      siftDown(minIndex)
    }
  }
}
