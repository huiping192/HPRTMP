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
    let url = URL(string: "rtmp://10.123.2.141:1935/stream")!
    let streamKey = "hello"
    let port = 1935
    socket = RTMPSocket(streamURL: url, streamKey: streamKey, port: port)
  }
  
  func run() {
    socket?.resume()
  }
}
