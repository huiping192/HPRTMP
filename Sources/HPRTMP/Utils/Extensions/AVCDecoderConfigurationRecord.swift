//
//  AVCDecoderConfigurationRecord.swift
//
//
//  Created by 郭 輝平 on 2023/10/16.
//

import Foundation

public struct AVCDecoderConfigurationRecord {
  // The version of the AVCDecoderConfigurationRecord, usually set to 1.
  private(set) var configurationVersion: UInt8 = 1
  
  // Indicates the profile code as per the H.264 specification.
  // This is extracted from the SPS NAL unit.
  private(set) var avcProfileIndication: UInt8 = 0
  
  // Indicates the compatibility of the stream.
  // This is also extracted from the SPS NAL unit.
  private(set) var profileCompatibility: UInt8 = 0
  
  // Indicates the level code as per the H.264 specification.
  // This is extracted from the SPS NAL unit.
  private(set) var avcLevelIndication: UInt8 = 0
  
  // Specifies the NAL unit length size minus one.
  // Default is 3, which means the NAL unit length is 4 bytes.
  private(set) var lengthSizeMinusOne: UInt8 = 3
  
  // An array containing the SPS NAL units.
  private(set) var spsList: [Data] = []
  
  // An array containing the PPS NAL units.
  private(set) var ppsList: [Data] = []
  
  // Initialize with avcDecoderConfigurationRecord data
  init?(avcDecoderConfigurationRecord data: Data) {
    guard data.count > 6 else {
      print("Invalid AVCDecoderConfigurationRecord data")
      return nil
    }
    
    var index = 0
    
    // Parse the header
    self.configurationVersion = data[index]; index += 1
    self.avcProfileIndication = data[index]; index += 1
    self.profileCompatibility = data[index]; index += 1
    self.avcLevelIndication = data[index]; index += 1
    self.lengthSizeMinusOne = data[index] & 0x03; index += 1 // Last 2 bits
    let numOfSPS = data[index] & 0x1F; index += 1 // Last 5 bits
    
    // Parse SPS
    for _ in 0..<numOfSPS {
      guard data.count > index + 1 else {
        print("Invalid SPS data")
        return nil
      }
      
      let spsLength = Int(data[index]) << 8 | Int(data[index + 1])
      index += 2
      
      guard data.count >= index + spsLength else {
        print("Invalid SPS data")
        return nil
      }
      
      let spsData = data[index..<(index + spsLength)]
      self.spsList.append(Data(spsData))
      index += spsLength
    }
    
    // Parse PPS
    guard data.count > index else {
      print("Invalid PPS data")
      return nil
    }
    
    let numOfPPS = data[index]; index += 1
    
    for _ in 0..<numOfPPS {
      guard data.count > index + 1 else {
        print("Invalid PPS data")
        return nil
      }
      
      let ppsLength = Int(data[index]) << 8 | Int(data[index + 1])
      index += 2
      
      guard data.count >= index + ppsLength else {
        print("Invalid PPS data")
        return nil
      }
      
      let ppsData = data[index..<(index + ppsLength)]
      self.ppsList.append(Data(ppsData))
      index += ppsLength
    }
  }
  
  // Initialize with SPS and PPS data
  init(sps: Data, pps: Data) {
    self.avcProfileIndication = sps[1]
    self.profileCompatibility = sps[2]
    self.avcLevelIndication = sps[3]
    
    // In the context of media containers like MP4 or streaming protocols like HLS, the lengthSizeMinusOne value is often set to 3, meaning that each NALU length is represented using 4 bytes (3 + 1). However, this value can also be 0, 1, or 2, representing 1, 2, or 3 bytes respectively.
    self.lengthSizeMinusOne = 3
 
    self.spsList = [sps]
    self.ppsList = [pps]
  }
  
  // Method to generate avcDecoderConfigurationRecord data
  func generateConfigurationRecord() -> Data {
    var body = Data()
    
    body.append(configurationVersion)
    body.append(avcProfileIndication)
    body.append(profileCompatibility)
    body.append(avcLevelIndication)
    
    body.append(0b11111100 | (self.lengthSizeMinusOne & 0b00000011))

    /*sps*/
    
    // numOfSequenceParameterSets
    let numOfSequenceParameterSets = 0b11100000 | (UInt8(spsList.count) & 0b00011111)
    body.append(Data([numOfSequenceParameterSets]))
    
    for sps in spsList {
      // sequenceParameterSetLength
      body.append(UInt16(sps.count).bigEndian.data)
      // sequenceParameterSetNALUnit
      body.append(Data(sps))
    }
    
    /*pps*/
    // numOfPictureParameterSets
    body.append(UInt8(ppsList.count))
    for pps in ppsList {
      // pictureParameterSetLength
      body.append(UInt16(pps.count).bigEndian.data)
      // pictureParameterSetNALUnit
      body.append(Data(pps))
    }
    
    return body
  }
}
