//
//  FrameConverter.swift
//  HPRTMPExample
//
//  Created by 郭 輝平 on 2023/08/24.
//

import Foundation
import AVFoundation


struct FrameConverter {
  
  func convertVideo(_ buffer: CMSampleBuffer) -> VideoFrame? {
    guard let bufferData = CMSampleBufferGetDataBuffer(buffer)?.data else {
      return nil
    }
    
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? [Any] else { return nil }
    guard let attachment = attachments[0] as? NSDictionary else {
      return nil
    }
    let isKeyframe = !(attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool ?? true)
    
    let pts = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) :  0
    let dts = buffer.decodeTimeStamp.seconds.isFinite ? UInt64(buffer.decodeTimeStamp.seconds * 1000) :  pts
    
    let frame = VideoFrame(data: bufferData, isKeyframe: isKeyframe, pts: pts, dts: dts)
    return frame
  }
  
  func convertAudio(_ buffer: CMSampleBuffer, aacHeader: Data) -> [AudioFrame]? {
    let numSamplesInBuffer = CMSampleBufferGetNumSamples(buffer);
    
    guard let aacData = getAACData(from: buffer) else { return nil}
        
    var audioFrames: [AudioFrame] = []
    var offset = 0
    
    for i in 0..<numSamplesInBuffer {
      let size = CMSampleBufferGetSampleSize(buffer, at: i)
      let data = aacData.subdata(in: offset..<offset + size)
      
      var timingInfo: CMSampleTimingInfo = CMSampleTimingInfo()
      CMSampleBufferGetSampleTimingInfo(buffer, at: i, timingInfoOut: &timingInfo)
      
      let pts = timingInfo.presentationTimeStamp.seconds.isFinite ? UInt64(timingInfo.presentationTimeStamp.seconds * 1000) : 0
      
      let audioFrame = AudioFrame(data: data, adtsHeader: aacHeader, pts: pts)
      audioFrames.append(audioFrame)
      
      offset += size
    }
    
    return audioFrames
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
}
