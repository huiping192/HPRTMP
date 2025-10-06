//
//  RTMPService.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2022/10/22.
//

import Foundation
import HPRTMP
import Combine

actor RTMPService: ObservableObject {
  private var session = RTMPPublishSession()
  private var streamMonitoringTasks: [Task<Void, Never>] = []
  
  let reader: MP4Reader
  
  var isRunning: Bool = false {
    didSet {
      isRunningSubject.send(isRunning)
    }
  }
  let isRunningSubject = PassthroughSubject<Bool, Never>()
  
  private var lastVideoTimestamp: UInt64 = 0
  private func setLastVideoTimestamp(_ lastVideoTimestamp: UInt64) {
    self.lastVideoTimestamp = lastVideoTimestamp
  }
  
  private var lastAudioTimestamp: UInt64 = 0
  private func setLastAudioTimestamp(_ lastAudioTimestamp: UInt64) {
    self.lastAudioTimestamp = lastAudioTimestamp
  }
  
  init() {
    let url = Bundle.main.url(forResource: "cloud9", withExtension: "mp4")!
    reader = MP4Reader(url: url)
    Task {
      await reader.setDelegate(self)
    }
  }
  
  func run() async {
    // Cancel previous monitoring tasks if any
    streamMonitoringTasks.forEach { $0.cancel() }
    streamMonitoringTasks.removeAll()

    // Monitor status stream
    let statusTask = Task { [session] in
      for await status in await session.statusStream {
        await handleStatusChange(status)
      }
    }
    streamMonitoringTasks.append(statusTask)

    // Monitor statistics stream
    let statisticsTask = Task { [session] in
      for await statistics in await session.statisticsStream {
        print("[test] \(statistics)")
      }
    }
    streamMonitoringTasks.append(statisticsTask)

    let publishConfig = PublishConfigure(width: 1280, height: 720, videocodecid: VideoData.CodecId.avc.rawValue, audiocodecid: AudioData.SoundFormat.aac.rawValue, framerate: 30, videoDatarate: 30, audioDatarate: nil, audioSamplerate: nil)
    await session.publish(url: "rtmp://192.168.11.23:1936/live/haha", configure: publishConfig)

    isRunning = true
  }

  private func handleStatusChange(_ status: RTMPPublishSession.Status) async {
    if status == .publishStart {
      await reader.start()
    }
  }
  
  private let serialQueue = DispatchQueue(label: "com.example.serialQueue")

  func stop() async {
    await reader.stop()
    lastVideoTimestamp = 0
    lastAudioTimestamp = 0
    await self.session.invalidate()

    // Cancel monitoring tasks
    streamMonitoringTasks.forEach { $0.cancel() }
    streamMonitoringTasks.removeAll()

    isRunning = false
  }
}

extension RTMPService: MP4ReaderDelegate {
  func output(stopped reader: MP4Reader) async {
    await stop()
  }
  
  func output(reader: MP4Reader, videoHeader: Data) async {
    await self.session.publishVideoHeader(data: videoHeader)
  }
  
  func output(reader: MP4Reader, audioHeader: Data) async {
    await self.session.publishAudioHeader(data: audioHeader)
  }
  
  func output(reader: MP4Reader, videoFrame: VideoFrame) async {
    var descData = Data()
    let frameType = videoFrame.isKeyframe ? VideoData.FrameType.keyframe : VideoData.FrameType.inter
    let frameAndCode:UInt8 = UInt8(frameType.rawValue << 4 | VideoData.CodecId.avc.rawValue)
    descData.append(Data([frameAndCode]))
    descData.append(Data([VideoData.AVCPacketType.nalu.rawValue]))
    
    let lastVideoTimestamp = self.lastVideoTimestamp
    let delta: UInt32 = UInt32(videoFrame.dts - lastVideoTimestamp)
    // 24bit
    let compositionTime = Int32(videoFrame.pts - videoFrame.dts)
    descData.write24(compositionTime, bigEndian: true)
    descData.append(videoFrame.data)
    
    print("[debug] video time:\(videoFrame.dts), delta \(delta)")
    await self.session.publishVideo(data: descData, delta: UInt32(delta))
    
    self.setLastVideoTimestamp(videoFrame.dts)
  }

  func output(reader: MP4Reader, audioFrame: AudioFrame) async {
    var audioPacketData = Data()
    audioPacketData.append(audioFrame.adtsHeader)
    audioPacketData.write(AudioData.AACPacketType.raw.rawValue)
    audioPacketData.append(audioFrame.data)
    
    let lastAudioTimestamp = self.lastAudioTimestamp
    let delta: UInt32 = UInt32(audioFrame.pts - lastAudioTimestamp)
    print("[debug] audio time:\(audioFrame.pts) , delta \(delta)")
    await self.session.publishAudio(data: audioPacketData, delta: delta)
    
    self.setLastAudioTimestamp(audioFrame.pts)
  }
  
}
