//
//  File.swift
//  
//
//  Created by 郭 輝平 on 2023/06/24.
//

import Foundation
import AVFoundation

struct MP4Reader {
  
  private let url: URL
  
  private var assetReader: AVAssetReader?
  
  init(url: URL) {
    self.url = url
  }
  
  func start() {
    assetReader?.startReading()
  }
  
  mutating func processMP4() {
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
    
    
    while let videoSampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
      handleVideoBuffer(buffer: videoSampleBuffer)
    }
    
    while let audioSampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
      handleAudioBuffer(buffer: audioSampleBuffer)
    }
    
    self.assetReader = assetReader
  }
  
  private func handleVideoBuffer(buffer: CMSampleBuffer ) {
    
  }
  
  private func handleAudioBuffer(buffer: CMSampleBuffer) {
    
  }
  
  private func getVideoHeader(buffer: CMSampleBuffer) {
    // SPS & PPS data
    guard let formatDescription = CMSampleBufferGetFormatDescription(buffer) else { return }
    let parameterSetCount = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
    
    if parameterSetCount > 2 {
      var pointerSPS: UnsafePointer<UInt8>?
      var pointerPPS: UnsafePointer<UInt8>?
      var sizeSPS: size_t = 0
      var sizePPS: size_t = 0
      var lengthSPS: Int32 = 0
      var lengthPPS: Int32 = 0
      
      CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 0, parameterSetPointerOut: &pointerSPS, parameterSetSizeOut: &sizeSPS, parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthSPS)
      
      CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 1, parameterSetPointerOut: &pointerPPS, parameterSetSizeOut: &sizePPS, parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthPPS)
      
      // Now you have your SPS & PPS data:
      let spsData = Data(bytes: pointerSPS!, count: sizeSPS)
      let ppsData = Data(bytes: pointerPPS!, count: sizePPS)
    }
  }
}
