//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/06/24.
//

import Foundation
import AVFoundation
import HPRTMP
 
protocol MP4ReaderDelegate: AnyObject {
  func output(reader: MP4Reader, videoHeader: Data) async
  func output(reader: MP4Reader, audioHeader: Data) async
  
  func output(reader: MP4Reader, videoFrame: VideoFrame) async
  func output(reader: MP4Reader, audioFrame: AudioFrame) async
}


protocol Frame {
  var data: Data { get }
  var ts: UInt64 { get }
}

struct VideoFrame: Frame {
  var data: Data
  let isKeyframe: Bool
  let pts: UInt64
  let dts: UInt64
  
  var ts: UInt64 {
    dts
  }
}

struct AudioFrame: Frame {
  var data: Data
  let adtsHeader: Data
  let pts: UInt64
  
  var ts: UInt64 {
    pts
  }
}

actor MP4Reader {
  
  private let url: URL
  
  private var assetReader: AVAssetReader?
  private var audioReaderOutput: AVAssetReaderTrackOutput?
  private var videoReaderOutput: AVAssetReaderTrackOutput?
  
  weak var delegate: (any MP4ReaderDelegate)?

  func setDelegate(_ delegate: MP4ReaderDelegate?) {
    self.delegate = delegate
  }
  
  
  private var videoTrack: AVAssetTrack?
  private var audioTrack: AVAssetTrack?
    
  private var frameQueue: [Frame] = []
  private var frameSendTask: Task<Void,Error>? = nil
  private let frameConverter = FrameConverter()
  
  
  init(url: URL) {
    self.url = url
  }
  
  func start() {
    Task {
      processMP4()
      assetReader?.startReading()
      
      
      // precache frames
      (0..<10).forEach { _ in
        if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
          if let frame = frameConverter.convertVideo(videoSampleBuffer) {
            self.frameQueue.append(frame)
            frameQueue.sort { $0.ts < $1.ts }
          }
        }
        if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
          if let frame = frameConverter.convertAudio(audioSampleBuffer, aacHeader: self.aacHeader!) {
            self.frameQueue.append(contentsOf: frame)
            frameQueue.sort { $0.ts < $1.ts }
          }
        }
      }
      
      
      
      // send video and audio header
      await self.delegate?.output(reader: self, videoHeader: videoHeader)
      await delegate?.output(reader: self, audioHeader: audioHeader!)

      // start send frames
      frameSendTask = Task {
        while !Task.isCancelled {
          asyncReadBuffer()
          
          let delta = await self.sendNextFrame()
          try? await Task.sleep(nanoseconds:  UInt64(10 * 1000 * 1000))
        }
      }
    }
  }
  
  func stop() {
    frameSendTask?.cancel()
    assetReader?.cancelReading()
    
    frameQueue = []
  }
  
  func sendNextFrame() async -> UInt64 {
    guard !frameQueue.isEmpty else { return 0 }
    print("[debug] queue size: \(frameQueue.count)")
    var delta: UInt64 = 0
    let firstFrame = frameQueue.removeFirst()
    if let nextFrame = frameQueue.first {
      if nextFrame.ts > firstFrame.ts {
        delta = nextFrame.ts - firstFrame.ts
      }
    }
    
    await sendFrame(frame: firstFrame)
    
    asyncReadBuffer()
    
    return delta
  }
  
  func sendFrame(frame: Frame) async {
    switch frame {
    case let videoFrame as VideoFrame:
      await delegate?.output(reader: self, videoFrame: videoFrame)
    case let audioFrame as AudioFrame:
      await delegate?.output(reader: self, audioFrame: audioFrame)
    default:
      break
    }
  }
    
  private func asyncReadBuffer() {
    Task {
      readVideoBuffer()
      readAudioBuffer()
    }
  }
  
  private func readVideoBuffer() {
    if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
      if let frame = frameConverter.convertVideo(videoSampleBuffer) {
        self.frameQueue.append(frame)
        frameQueue.sort { $0.ts < $1.ts }
      }
    }
  }
  
  private func readAudioBuffer() {
    if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
      if let frame = frameConverter.convertAudio(audioSampleBuffer, aacHeader: self.aacHeader!) {
        self.frameQueue.append(contentsOf: frame)
        frameQueue.sort { $0.ts < $1.ts }
      }
    }
  }
  
  func processMP4() {
    let asset = AVURLAsset(url: url)
    guard let assetReader = try? AVAssetReader(asset: asset) else {
      print("Unable to create AVAssetReader")
      return
    }
    
    // Get video track
    let videoTrack = asset.tracks(withMediaType: .video).first
    let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: nil)
    videoReaderOutput.alwaysCopiesSampleData = false
    assetReader.add(videoReaderOutput)
    
    let audioTrack = asset.tracks(withMediaType: .audio).first
    let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil)
    audioReaderOutput.alwaysCopiesSampleData = false
    assetReader.add(audioReaderOutput)
    
    self.assetReader = assetReader
    self.audioReaderOutput = audioReaderOutput
    self.videoReaderOutput = videoReaderOutput
    
    self.videoTrack = videoTrack
    self.audioTrack = audioTrack
  }
  
  private var audioHeader: Data? {
    let formatDescription = audioTrack?.formatDescriptions.first as! CMFormatDescription
    
    // Get the ASBD from the format description
    guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return nil }
    var outFormatDescription: CMFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &outFormatDescription)
    
    
    guard let streamBasicDesc = outFormatDescription?.streamBasicDesc else {
      return nil
    }
    let mp4Id: MPEG4ObjectID
    if streamBasicDesc.mFormatFlags == 0 { // default lc
      mp4Id = .AAC_LC
    } else {
      mp4Id = MPEG4ObjectID(rawValue: Int(streamBasicDesc.mFormatFlags))!
    }
    var descData = Data()
    let sampeRate = streamBasicDesc.mSampleRate
    let config = AudioSpecificConfig(objectType: mp4Id,
                                     channelConfig: ChannelConfigType(rawValue: UInt8(streamBasicDesc.mChannelsPerFrame)),
                                     frequencyType: SampleFrequencyType(value: sampeRate))
    
    descData.append(aacHeader!)
    descData.write(AudioData.AACPacketType.header.rawValue)
    descData.append(config.encodeData)
    (0..<14).forEach { _ in
      descData.write(UInt8(0))
    }
    
    return descData
  }
  
  private var aacHeader: Data? {
    let formatDescription = audioTrack?.formatDescriptions.first as! CMFormatDescription
    
    // Get the ASBD from the format description
    guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return nil }

    var outFormatDescription: CMFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &outFormatDescription)
    
    return aacHeader(outFormatDescription: outFormatDescription)
  }
  
  /*
   Sound format: a 4-bit field that indicates the audio format, such as AAC or MP3.
   Sound rate: a 2-bit field that indicates the audio sample rate, such as 44.1 kHz or 48 kHz.
   Sound size: a 1-bit field that indicates the audio sample size, such as 16-bit or 8-bit.
   Sound type: a 1-bit field that indicates the audio channel configuration, such as stereo or mono.
   */
  func aacHeader(outFormatDescription: CMFormatDescription?) -> Data {
    guard let desc = outFormatDescription,
          let streamBasicDesc = desc.streamBasicDesc else {
      return Data()
    }
    let value = (AudioData.SoundFormat.aac.rawValue << 4 |
                 AudioData.SoundRate(value: streamBasicDesc.mSampleRate).rawValue << 2 |
                 AudioData.SoundSize.snd16Bit.rawValue << 1 |
                 AudioData.SoundType.sndStereo.rawValue)
    return Data([UInt8(value)])
  }
  
  private var videoHeader: Data {
    // SPS & PPS data
    let formatDescription = videoTrack?.formatDescriptions.first as! CMFormatDescription

    
    var pointerSPS: UnsafePointer<UInt8>?
    var pointerPPS: UnsafePointer<UInt8>?
    var sizeSPS: size_t = 0
    var sizePPS: size_t = 0
    var lengthSPS: Int32 = 0
    var lengthPPS: Int32 = 0
    
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 0, parameterSetPointerOut: &pointerSPS, parameterSetSizeOut: &sizeSPS, parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthSPS)
    
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 1, parameterSetPointerOut: &pointerPPS, parameterSetSizeOut: &sizePPS, parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthPPS)
    
    // Now you have your SPS & PPS data:
    let sps = Data(bytes: pointerSPS!, count: sizeSPS)
    let pps = Data(bytes: pointerPPS!, count: sizePPS)
    
    var body = Data()
    body.append(Data([0x17]))
    body.append(Data([0x00]))
    
    body.append(Data([0x00, 0x00, 0x00]))
    
    body.append(Data([0x01]))
    
    let spsSize = sps.count
    
    body.append(Data([sps[1], sps[2], sps[3], 0xff]))
    
    /*sps*/
    body.append(Data([0xe1]))
    body.append(Data([(UInt8(spsSize) >> 8) & 0xff, UInt8(spsSize) & 0xff]))
    body.append(Data(sps))
    
    let ppsSize = pps.count
    
    /*pps*/
    body.append(Data([0x01]))
    body.append(Data([(UInt8(ppsSize) >> 8) & 0xff, UInt8(ppsSize) & 0xff]))
    body.append(Data(pps))
        
    return body
  }
  
}

