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
    
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? NSArray else { return nil }
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
    let timestamp = buffer.presentationTimeStamp.seconds.isFinite ? UInt64(buffer.presentationTimeStamp.seconds * 1000) : 0
    
    if numSamplesInBuffer == 1 {
      let audioFrame = AudioFrame(data: aacData, adtsHeader: aacHeader, pts: timestamp)
      return [audioFrame]
    } else {
      let size1 = CMSampleBufferGetSampleSize(buffer, at: 0)
      let size2 = CMSampleBufferGetSampleSize(buffer, at: 1)
      
      let data1 = aacData.subdata(in: 0..<size1)
      let data2 = aacData.subdata(in: size1..<size1+size2)
      
      var timingInfo1: CMSampleTimingInfo = CMSampleTimingInfo()
      CMSampleBufferGetSampleTimingInfo(buffer, at: 0, timingInfoOut: &timingInfo1)
      
      let pts1 = timingInfo1.presentationTimeStamp.seconds.isFinite ? UInt64(timingInfo1.presentationTimeStamp.seconds * 1000) : 0
      
      let audioFrame = AudioFrame(data: data1, adtsHeader: aacHeader, pts: pts1)
      
      
      var timingInfo2: CMSampleTimingInfo = CMSampleTimingInfo()
      CMSampleBufferGetSampleTimingInfo(buffer, at: 1, timingInfoOut: &timingInfo2)
      
      let pts2 = timingInfo2.presentationTimeStamp.seconds.isFinite ? UInt64(timingInfo2.presentationTimeStamp.seconds * 1000) : 0
      
      let audioFrame2 = AudioFrame(data: data2, adtsHeader: aacHeader, pts: pts2)
      return [audioFrame,audioFrame2]
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
}
