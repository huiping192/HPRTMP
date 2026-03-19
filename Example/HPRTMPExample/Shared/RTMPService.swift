//
//  RTMPService.swift
//  HPRTMPExample
//
//  Created by Huiping Guo on 2022/10/22.
//

import Foundation
import HPRTMP

@MainActor
class RTMPService: ObservableObject {
  @Published var connectionStatus: RTMPSessionStatus = .unknown
  @Published var statistics: TransmissionStatistics? = nil
  @Published var isRunning: Bool = false
  @Published var errorMessage: String? = nil

  private var session = RTMPPublishSession()
  private var streamMonitoringTasks: [Task<Void, Never>] = []

  let reader: MP4Reader

  private var lastVideoTimestamp: UInt64 = 0
  private var lastAudioTimestamp: UInt64 = 0

  init() {
    let url = Bundle.main.url(forResource: "cloud9", withExtension: "mp4")!
    reader = MP4Reader(url: url)
    Task {
      await reader.setDelegate(self)
    }
  }

  func run(url: String) async {
    guard url.hasPrefix("rtmp://") || url.hasPrefix("rtmps://") else {
      errorMessage = "Invalid URL: must start with rtmp:// or rtmps://"
      return
    }

    errorMessage = nil

    streamMonitoringTasks.forEach { $0.cancel() }
    streamMonitoringTasks.removeAll()

    let statusTask = Task { [weak self] in
      guard let self else { return }
      for await status in await session.statusStream {
        await self.handleStatusChange(status)
      }
    }
    streamMonitoringTasks.append(statusTask)

    let statisticsTask = Task { [weak self] in
      guard let self else { return }
      var lastUpdate = Date.distantPast
      for await stats in await session.statisticsStream {
        let now = Date()
        // 1 秒节流，避免过度刷新
        if now.timeIntervalSince(lastUpdate) >= 1.0 {
          self.statistics = stats
          lastUpdate = now
        }
      }
    }
    streamMonitoringTasks.append(statisticsTask)

    let publishConfig = PublishConfigure(
      width: 1280, height: 720,
      videocodecid: VideoData.CodecId.avc.rawValue,
      audiocodecid: AudioData.SoundFormat.aac.rawValue,
      framerate: 30,
      videoDatarate: 30,
      audioDatarate: nil,
      audioSamplerate: nil
    )
    await session.publish(url: url, configure: publishConfig)

    isRunning = true
  }

  private func handleStatusChange(_ status: RTMPSessionStatus) async {
    connectionStatus = status
    switch status {
    case .publishStart:
      await reader.start()
    case .failed(let err):
      errorMessage = err.localizedDescription
      isRunning = false
    case .disconnected:
      isRunning = false
      statistics = nil
    default:
      break
    }
  }

  func stop() async {
    await reader.stop()
    lastVideoTimestamp = 0
    lastAudioTimestamp = 0
    await session.stop()

    streamMonitoringTasks.forEach { $0.cancel() }
    streamMonitoringTasks.removeAll()

    isRunning = false
    connectionStatus = .unknown
    statistics = nil
  }
}

extension RTMPService: MP4ReaderDelegate {
  func output(stopped reader: MP4Reader) async {
    await stop()
  }

  func output(reader: MP4Reader, videoHeader: Data) async {
    await session.publishVideoHeader(data: videoHeader)
  }

  func output(reader: MP4Reader, audioHeader: Data) async {
    await session.publishAudioHeader(data: audioHeader)
  }

  func output(reader: MP4Reader, videoFrame: VideoFrame) async {
    var descData = Data()
    let frameType = videoFrame.isKeyframe ? VideoData.FrameType.keyframe : VideoData.FrameType.inter
    let frameAndCode: UInt8 = UInt8(frameType.rawValue << 4 | VideoData.CodecId.avc.rawValue)
    descData.append(Data([frameAndCode]))
    descData.append(Data([VideoData.AVCPacketType.nalu.rawValue]))

    let delta: UInt32 = UInt32(videoFrame.dts - lastVideoTimestamp)
    let compositionTime = Int32(videoFrame.pts - videoFrame.dts)
    descData.write24(compositionTime, bigEndian: true)
    descData.append(videoFrame.data)

    await session.publishVideo(data: descData, delta: UInt32(delta))
    lastVideoTimestamp = videoFrame.dts
  }

  func output(reader: MP4Reader, audioFrame: AudioFrame) async {
    var audioPacketData = Data()
    audioPacketData.append(audioFrame.adtsHeader)
    audioPacketData.write(AudioData.AACPacketType.raw.rawValue)
    audioPacketData.append(audioFrame.data)

    let delta: UInt32 = UInt32(audioFrame.pts - lastAudioTimestamp)
    await session.publishAudio(data: audioPacketData, delta: delta)
    lastAudioTimestamp = audioFrame.pts
  }
}
