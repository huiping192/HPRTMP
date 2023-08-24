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


struct VideoFrame {
  let data: Data
  let isKeyframe: Bool
  let pts: UInt64
  let dts: UInt64
}

struct AudioFrame {
  let data: Data
  let adtsHeader: Data
  let pts: UInt64
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
  
    
  private var videoQueue: [CMSampleBuffer] = []
  private var audioQueue: [CMSampleBuffer] = []
  
  private var videoSendTask: Task<Void,Error>? = nil
  private var audioSendTask: Task<Void,Error>? = nil
  
  init(url: URL) {
    self.url = url
  }
  
  func start() {
    processMP4()
    
    
    assetReader?.startReading()
    
    (0..<10).forEach { _ in
      if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
        self.videoQueue.append(videoSampleBuffer)
      }
      if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
        self.audioQueue.append(audioSampleBuffer)
      }
    }

    videoSendTask = Task {
      await self.getVideoHeader()

      while !Task.isCancelled {
        let delta = await self.sendVideoFrame()
        try? await Task.sleep(nanoseconds:  UInt64(delta * 1000 * 1000))
      }
    }

    audioSendTask = Task {
      await self.getAudioHeader()

      while !Task.isCancelled {
        let delta = await self.sendAudioFrame()
        try? await Task.sleep(nanoseconds: UInt64(delta * 1000 * 1000))
      }
    }
  }
  
  func stop() {
    videoSendTask?.cancel()
    audioSendTask?.cancel()
    assetReader?.cancelReading()
    
    videoQueue = []
    audioQueue = []
  }
  
  func sendVideoFrame() async -> UInt32 {
    var delta: UInt32 = 0
    guard let videoBuffer = videoQueue.first else {
      return delta
    }
    
    if videoQueue.count >= 2 {
      let nextVideoBuffer = videoQueue[1]
      let pts1 = videoBuffer.presentationTimeStamp.seconds.isFinite ? UInt64(videoBuffer.presentationTimeStamp.seconds * 1000) :  0
      let pts2 = nextVideoBuffer.presentationTimeStamp.seconds.isFinite ? UInt64(nextVideoBuffer.presentationTimeStamp.seconds * 1000) :  0

      let dts1 = videoBuffer.decodeTimeStamp.seconds.isFinite ? UInt64(videoBuffer.decodeTimeStamp.seconds * 1000) : pts1
      let dts2 = nextVideoBuffer.decodeTimeStamp.seconds.isFinite ? UInt64(nextVideoBuffer.decodeTimeStamp.seconds * 1000) : pts2

      if dts2 > dts1 {
        delta = UInt32(dts2 - dts1)
      }
    }
    
    self.videoQueue.removeFirst()
    await self.handleVideoBuffer(buffer: videoBuffer)
    
    asyncReadVideoBuffer()
    
    return delta
  }
  
  private func asyncReadVideoBuffer() {
    Task {
      if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
        self.videoQueue.append(videoSampleBuffer)
      }
    }
  }
  
  func sendAudioFrame() async -> UInt32 {
    var delta: UInt32 = 0
    guard let buffer = audioQueue.first else {
      return delta
    }
    
    if audioQueue.count >= 2 {
      let nextBuffer = audioQueue[1]
      
      let pts1 = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) :  0
      let pts2 = nextBuffer.presentationTimeStamp.seconds.isFinite ? UInt64(nextBuffer.presentationTimeStamp.seconds * 1000) :  0
      
      delta = UInt32(pts2 - pts1)
    }
    
    self.audioQueue.removeFirst()
    await self.handleAudioBuffer(buffer: buffer)
    
    asyncReadAudioBuffer()
    
    return delta
  }
  
  private func asyncReadAudioBuffer() {
    Task {
      if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
        self.audioQueue.append(audioSampleBuffer)
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
  
  private func handleVideoBuffer(buffer: CMSampleBuffer ) async {
    guard let bufferData = CMSampleBufferGetDataBuffer(buffer)?.data else {
      return
    }
    
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? NSArray else { return }
    guard let attachment = attachments[0] as? NSDictionary else {
      return
    }
    let isKeyframe = !(attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool ?? true)
  
    let pts = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) :  0
    let dts = buffer.decodeTimeStamp.seconds.isFinite ? UInt64(buffer.decodeTimeStamp.seconds * 1000) :  pts
    
    let frame = VideoFrame(data: bufferData, isKeyframe: isKeyframe, pts: pts, dts: dts)
    await delegate?.output(reader: self, videoFrame: frame)
  }
  
  private func handleAudioBuffer(buffer: CMSampleBuffer) async {
    let numSamplesInBuffer = CMSampleBufferGetNumSamples(buffer);
    print("[debug audio] buffer samples: \(numSamplesInBuffer)")
    
    guard let aacHeader = aacHeader else { return }
    guard let aacData = getAACData(from: buffer) else { return }
    let timestamp = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) : 0
    
    if numSamplesInBuffer == 1 {
      let audioFrame = AudioFrame(data: aacData, adtsHeader: aacHeader, pts: timestamp)
      await delegate?.output(reader: self, audioFrame: audioFrame)
    } else {
      let size1 = CMSampleBufferGetSampleSize(buffer, at: 0)
      let size2 = CMSampleBufferGetSampleSize(buffer, at: 1)

      let data1 = aacData.subdata(in: 0..<size1)
      let data2 = aacData.subdata(in: size1..<size1+size2)
      
      var timingInfo1: CMSampleTimingInfo = CMSampleTimingInfo()
      CMSampleBufferGetSampleTimingInfo(buffer, at: 0, timingInfoOut: &timingInfo1)
      
      let pts1 = timingInfo1.presentationTimeStamp.seconds.isFinite ? UInt64(timingInfo1.presentationTimeStamp.seconds * 1000) : 0

      let audioFrame = AudioFrame(data: data1, adtsHeader: aacHeader, pts: pts1)
      await delegate?.output(reader: self, audioFrame: audioFrame)
      
      
      var timingInfo2: CMSampleTimingInfo = CMSampleTimingInfo()
      CMSampleBufferGetSampleTimingInfo(buffer, at: 1, timingInfoOut: &timingInfo2)
      
      let pts2 = timingInfo2.presentationTimeStamp.seconds.isFinite ? UInt64(timingInfo2.presentationTimeStamp.seconds * 1000) : 0

      let audioFrame2 = AudioFrame(data: data2, adtsHeader: aacHeader, pts: pts2)
      await delegate?.output(reader: self, audioFrame: audioFrame2)
    }
  }
    
  func getAACData(from sampleBuffer: CMSampleBuffer) -> Data? {
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
      print("Could not get block buffer from sample buffer")
      return nil
    }
    
    let length = CMBlockBufferGetDataLength(blockBuffer)
    var dataPointer: UnsafeMutablePointer<Int8>? = nil
    
    CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
    
    if let dataPointer = dataPointer {
      return Data(bytes: dataPointer, count: length)
    }
    
    return nil
  }
  
  
  private func getAudioHeader() async {
    let formatDescription = audioTrack?.formatDescriptions.first as! CMFormatDescription
    
    // Get the ASBD from the format description
    guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return }
    var outFormatDescription: CMFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &outFormatDescription)
    
    
    guard let streamBasicDesc = outFormatDescription?.streamBasicDesc else {
      return
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
    
    let aacHeader = aacHeader(outFormatDescription: outFormatDescription)
    self.aacHeader = aacHeader
    descData.append(aacHeader)
    descData.write(AudioData.AACPacketType.header.rawValue)
    descData.append(config.encodeData)
    (0..<14).forEach { _ in
      descData.write(UInt8(0))
    }
    
    await delegate?.output(reader: self, audioHeader: descData)
  }
  
  private var aacHeader: Data?
  
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
  
  private func getVideoHeader() async {
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
        
    await delegate?.output(reader: self, videoHeader: body)
  }
  
}

