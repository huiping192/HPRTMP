//
//  RTMPService.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2022/10/22.
//

import Foundation
import HPRTMP

class RTMPService {
  
  private var session = RTMPPublishSession()
  
  init() {
//    let url = URL(string: "rtmp://192.168.11.23/live")!
//    let streamKey = "hello"
//    let port = 1935
//    socket.connect(streamURL: url, streamKey: streamKey, port: port)
  }
  
  func run() {
    let publishConfig = PublishConfigure(
      width: 640,
      height: 480,
      displayWidth: 640,
      displayHeight: 480,
      videocodecid: VideoData.CodecId.avc.rawValue,
      audiocodecid: AudioData.SoundFormat.aac.rawValue,
      framerate: 30,
      videoframerate: 30
    )
    
    session.publish(url: "rtmp://192.168.11.23/live/haha", configure: publishConfig)
  }
}
