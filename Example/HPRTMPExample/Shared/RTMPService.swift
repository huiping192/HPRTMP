//
//  RTMPService.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2022/10/22.
//

import Foundation
import HPRTMP

actor RTMPService: RTMPPublishSessionDelegate {
  func sessionStatusChange(_ session: HPRTMP.RTMPPublishSession, status: HPRTMP.RTMPPublishSession.Status) {
    if status == .publishStart {
      reader.start()
    }
  }
  
  func sessionError(_ session: HPRTMP.RTMPPublishSession, error: HPRTMP.RTMPError) {
    
  }
  
  
  private var session = RTMPPublishSession()
  
  var reader: MP4Reader
  
  private var lastVideoTimestamp: UInt64 = 0
  private func setLastVideoTimestamp(_ lastVideoTimestamp: UInt64) {
    self.lastVideoTimestamp = lastVideoTimestamp
  }
  
  private var lastAudioTimestamp: UInt64 = 0
  private func setLastAudioTimestamp(_ lastAudioTimestamp: UInt64) {
    self.lastAudioTimestamp = lastAudioTimestamp
  }
  
  init() {
    let url = Bundle.main.url(forResource: "sample", withExtension: "mp4")!
    reader = MP4Reader(url: url)
    reader.delegate = self
  }
  
  func run() async {
    await session.setDelegate(self)
    let publishConfig = PublishConfigure(width: 960, height: 720, videocodecid: VideoData.CodecId.avc.rawValue, audiocodecid: AudioData.SoundFormat.aac.rawValue, framerate: 24, videoDatarate: 24, audioDatarate: nil, audioSamplerate: nil)
    await session.publish(url: "rtmp://a.rtmp.youtube.com/live2/18jg-kdbm-5zzb-pcjm-7084", configure: publishConfig)
  }
  
  
  func stop() async {
    reader.stop()
    await self.session.invalidate()
  }
}

extension RTMPService: MP4ReaderDelegate {
  nonisolated func output(reader: MP4Reader, videoHeader: Data) {
    Task {
      await self.session.publishVideoHeader(data: videoHeader, time: 0)
    }
  }
  
  nonisolated func output(reader: MP4Reader, audioHeader: Data) {
    Task {
      await self.session.publishAudioHeader(data: audioHeader)
    }
  }
  
  nonisolated func output(reader: MP4Reader, videoFrame: VideoFrame) {
    Task {
      var descData = Data()
      let frameType = videoFrame.isKeyframe ? VideoData.FrameType.keyframe : VideoData.FrameType.inter
      let frameAndCode:UInt8 = UInt8(frameType.rawValue << 4 | VideoData.CodecId.avc.rawValue)
      descData.append(Data([frameAndCode]))
      descData.append(Data([VideoData.AVCPacketType.nalu.rawValue]))
      
      let lastVideoTimestamp = await self.lastVideoTimestamp
      let delta: UInt32 = UInt32(videoFrame.dts - lastVideoTimestamp)
      // 24bit
      let compositionTime = Int32(videoFrame.pts - videoFrame.dts)
      descData.write24(compositionTime, bigEndian: true)
      descData.append(videoFrame.data)
      
      print("[debug] video time:\(videoFrame.pts), delta \(delta)")
      await self.session.publishVideo(data: descData, delta: UInt32(delta))
      
      await self.setLastVideoTimestamp(videoFrame.dts)
    }
  }
  
  nonisolated func output(reader: MP4Reader, audioFrame: AudioFrame) {
    Task {
      var audioPacketData = Data()
      audioPacketData.append(audioFrame.adtsHeader)
      audioPacketData.write(AudioData.AACPacketType.raw.rawValue)
      audioPacketData.append(audioFrame.data)

      let lastAudioTimestamp = await self.lastAudioTimestamp
      let delta: UInt32 = UInt32(audioFrame.pts - lastAudioTimestamp)
      print("[debug] audio time:\(audioFrame.pts) , delta \(delta)")
      await self.session.publishAudio(data: audioPacketData, delta: delta)
      
      await self.setLastAudioTimestamp(audioFrame.pts)
    }
  }
  
}
