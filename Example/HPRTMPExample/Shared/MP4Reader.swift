//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/06/24.
//

import Foundation
import AVFoundation
import HPRTMP

class MP4Reader {
  
  private let url: URL
  
  private var assetReader: AVAssetReader?
  private var audioReaderOutput: AVAssetReaderTrackOutput?
  private var videoReaderOutput: AVAssetReaderTrackOutput?
  
  private var videoTrack: AVAssetTrack?
  private var audioTrack: AVAssetTrack?
  
  private var displayLinkHandler: DisplayLinkHandler?

  var sendVideoBuffer: ((Data,Bool,UInt64,Int32) -> Void)?
  var sendAudioBuffer: ((Data,Data,UInt64) -> Void)?
  
  var sendVideoHeader: ((Data) -> Void)?
  var sendAudioHeader: ((Data) -> Void)?
    
  var videoQueue: [CMSampleBuffer] = []
  var audioQueue: [CMSampleBuffer] = []

  init(url: URL) {
    self.url = url
    
    processMP4()
    
    displayLinkHandler = DisplayLinkHandler(framerate: 44) {
      self.updateFrame()
    }
  }
  
  func start() {
    assetReader?.startReading()
    
    (0..<10).forEach { _ in
      if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
        let videoSampleBufferTimestamp = videoSampleBuffer.decodeTimeStamp.seconds.isFinite ? UInt64(videoSampleBuffer.decodeTimeStamp.seconds * 1000) :  UInt64(videoSampleBuffer.presentationTimeStamp.seconds * 1000)

        var insertIndex: Int? = nil
        for (index,buffer) in videoQueue.enumerated() {
          let timestamp = buffer.decodeTimeStamp.seconds.isFinite ? UInt64(buffer.decodeTimeStamp.seconds * 1000) :  UInt64(buffer.presentationTimeStamp.seconds * 1000)
          if timestamp > videoSampleBufferTimestamp {
            insertIndex = index
            break
          }
        }
        if let insertIndex = insertIndex {
          self.videoQueue.insert(videoSampleBuffer, at: insertIndex)
        } else {
          self.videoQueue.append(videoSampleBuffer)
        }
      }
      if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
        self.audioQueue.append(audioSampleBuffer)
      }
    }
    
    getVideoHeader()
    getAudioHeader()

    displayLinkHandler?.startUpdates()
  }
  
  func updateFrame() {
    var videoBuffer: CMSampleBuffer? = nil
    if !videoQueue.isEmpty {
      let videoSampleBuffer = self.videoQueue.first
      videoBuffer = videoSampleBuffer
    }
    
    var audioBuffer: CMSampleBuffer? = nil
    if !self.audioQueue.isEmpty {
      let audioSampleBuffer = self.audioQueue.first
      audioBuffer = audioSampleBuffer
    }
    
    let videoSampleBufferTimestamp = videoBuffer!.decodeTimeStamp.seconds.isFinite ? UInt64(videoBuffer!.decodeTimeStamp.seconds * 1000) :  UInt64(videoBuffer!.presentationTimeStamp.seconds * 1000)
    let audioSampleBufferTimestamp = UInt64((audioBuffer?.presentationTimeStamp.seconds ?? 0) * 1000)
    
    if videoSampleBufferTimestamp + 15 < audioSampleBufferTimestamp {
      if let buffer = videoBuffer {
        self.videoQueue.removeFirst()
        self.handleVideoBuffer(buffer: buffer)
      }
    } else {
      if let buffer = audioBuffer {
        self.audioQueue.removeFirst()
        self.handleAudioBuffer(buffer: buffer)
      }
    }
    
    
    if let audioSampleBuffer = self.audioReaderOutput?.copyNextSampleBuffer() {
      self.audioQueue.append(audioSampleBuffer)
    }
    if let videoSampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() {
      let videoSampleBufferTimestamp = videoSampleBuffer.decodeTimeStamp.seconds.isFinite ? UInt64(videoSampleBuffer.decodeTimeStamp.seconds * 1000) :  UInt64(videoSampleBuffer.presentationTimeStamp.seconds * 1000)
      var insertIndex: Int? = nil
      for (index,buffer) in videoQueue.enumerated() {
        let timestamp = buffer.decodeTimeStamp.seconds.isFinite ? UInt64(buffer.decodeTimeStamp.seconds * 1000) :  UInt64(buffer.presentationTimeStamp.seconds * 1000)
        if timestamp > videoSampleBufferTimestamp {
          insertIndex = index
          break
        }
      }
      if let insertIndex = insertIndex {
        self.videoQueue.insert(videoSampleBuffer, at: insertIndex)
      } else {
        self.videoQueue.append(videoSampleBuffer)
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
    assetReader.add(videoReaderOutput)
    
    let audioTrack = asset.tracks(withMediaType: .audio).first
    let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil)
    assetReader.add(audioReaderOutput)
    
    self.assetReader = assetReader
    self.audioReaderOutput = audioReaderOutput
    self.videoReaderOutput = videoReaderOutput
    
    self.videoTrack = videoTrack
    self.audioTrack = audioTrack
  }
  
  private func handleVideoBuffer(buffer: CMSampleBuffer ) {
    guard let bufferData = CMSampleBufferGetDataBuffer(buffer)?.data else {
      return
    }
    
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? NSArray else { return }
    
    guard let attachment = attachments[0] as? NSDictionary else {
      return
    }
    
    let isKeyframe = !(attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool ?? true)
    
    let presentationTimeStamp = buffer.presentationTimeStamp
    var decodeTimeStamp = buffer.decodeTimeStamp
    if decodeTimeStamp == .invalid {
      decodeTimeStamp = presentationTimeStamp
    }
    let timestamp = buffer.decodeTimeStamp.seconds.isFinite ? UInt64(buffer.decodeTimeStamp.seconds * 1000) :  UInt64(buffer.presentationTimeStamp.seconds * 1000)
    let compositionTime = Int32((presentationTimeStamp.seconds - decodeTimeStamp.seconds) * 1000)
    
    self.sendVideoBuffer?(bufferData,isKeyframe,timestamp,compositionTime)
  }
  
  private func handleAudioBuffer(buffer: CMSampleBuffer) {
    guard let aacHeader = aacHeader else { return }
    guard let data = getAACData(from: buffer) else { return }
    
    let timestamp = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) : 0
    sendAudioBuffer?(data, aacHeader, timestamp)
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
  
  
  private func getAudioHeader() {
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
    self.sendAudioHeader?(descData)
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
  
  private func getVideoHeader() {
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
    
    sendVideoHeader?(body)
  }
  
}



extension CMBlockBuffer {
  var data: Data? {
    var length: Int = 0
    var pointer: UnsafeMutablePointer<Int8>?
    guard CMBlockBufferGetDataPointer(self, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
          let p = pointer else {
      return nil
    }
    return Data(bytes: p, count: length)
  }
  
  var length: Int {
    return CMBlockBufferGetDataLength(self)
  }
  
}

extension CMAudioFormatDescription {
  
  var streamBasicDesc: AudioStreamBasicDescription? {
    get {
      return CMAudioFormatDescriptionGetStreamBasicDescription(self)?.pointee
    }
  }
}


/*
 AudioSpecificConfig = 2 bytes,
 number = bits
 ------------------------------
 | audioObjectType (5)        |
 | sampleingFrequencyIndex (4)|
 | channelConfigration (4)    |
 | frameLengthFlag (1)        |
 | dependsOnCoreCoder (1)     |
 | extensionFlag (1)          |
 ------------------------------
 */
struct AudioSpecificConfig {
  let objectType: MPEG4ObjectID
  var channelConfig: ChannelConfigType = .unknown
  var frequencyType: SampleFrequencyType = .unknown
  let frameLengthFlag: Bool
  let dependsOnCoreCoder: UInt8
  let extensionFlag: UInt8
  init (data: Data) {
    self.objectType = MPEG4ObjectID(rawValue: Int((0b11111000 & data[0]) >> 3)) ?? .aac_Main
    self.frequencyType = SampleFrequencyType(rawValue: (0b00000111 & data[0]) << 1 | (0b10000000 & data[1]) >> 7)
    self.channelConfig = ChannelConfigType(rawValue: (0b01111000 & data[1]) >> 3)
    let value = UInt8(data[1] & 0b00100000) == 1
    self.frameLengthFlag = value
    self.dependsOnCoreCoder = data[1] & 0b000000010
    self.extensionFlag = data[1] & 0b000000001
  }
  
  init(objectType: MPEG4ObjectID, channelConfig: ChannelConfigType, frequencyType: SampleFrequencyType, frameLengthFlag: Bool = false, dependsOnCoreCoder: UInt8 = 0, extensionFlag: UInt8 = 0) {
    self.objectType = objectType
    self.channelConfig = channelConfig
    self.frequencyType = frequencyType
    self.frameLengthFlag = frameLengthFlag
    self.dependsOnCoreCoder = dependsOnCoreCoder
    self.extensionFlag = extensionFlag
  }
  
  var encodeData: Data {
    get {
      let flag = self.frameLengthFlag ? 1 : 0
      let first = UInt8(self.objectType.rawValue) << 3 | UInt8(self.frequencyType.rawValue >> 1 & 0b00000111)
      let second = (0b10000000 & self.frequencyType.rawValue << 7) |
      (0b01111000 & self.channelConfig.rawValue << 3) |
      (UInt8(flag) << 2) |
      (self.dependsOnCoreCoder << 1) |
      self.extensionFlag
      return Data([first, second])
    }
  }
}


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





