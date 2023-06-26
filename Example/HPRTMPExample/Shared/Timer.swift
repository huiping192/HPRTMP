//
//  Timer.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2023/06/26.
//

import Foundation
import UIKit

class DisplayLinkTarget {
    let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    @objc func onDisplayLinkUpdate() {
        callback()
    }
}

class DisplayLinkHandler {
  private var displayLink: CADisplayLink?
  private var displayLinkTarget: DisplayLinkTarget?
  
  private let framerate: Int
  
  init(framerate: Int = 30, updateClosure: @escaping () -> Void) {
    self.framerate = framerate
    self.displayLinkTarget = DisplayLinkTarget(callback: updateClosure)
  }
  
  func startUpdates() {
    guard let target = displayLinkTarget else {
      return
    }
    
    self.displayLink = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.onDisplayLinkUpdate))
    self.displayLink?.preferredFramesPerSecond = framerate
    self.displayLink?.add(to: .main, forMode: .default)
  }
  
  func stopUpdates() {
    self.displayLink?.invalidate()
    self.displayLink = nil
  }
}





