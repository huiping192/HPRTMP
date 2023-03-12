//
//  RTMPService.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2022/10/22.
//

import Foundation
import HPRTMP

class RTMPService {
  
  private var socket: RTMPSocket!
  
  init() {
    let url = URL(string: "rtmp://192.168.11.23/live")!
    let streamKey = "hello"
    let port = 1935
    socket = RTMPSocket(streamURL: url, streamKey: streamKey, port: port)
  }
  
  func run() {
    socket?.resume()
  }
}
