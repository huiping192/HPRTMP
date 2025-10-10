//
//  File.swift
//
//
//  Created by 郭 輝平 on 2023/10/16.
//

import Foundation
import XCTest

@testable import HPRTMP

class AVCDecoderConfigurationRecordTests: XCTestCase {
  
  func testInitWithValidData() {
    // Prepare a mock AVCDecoderConfigurationRecord data
    let mockData: Data = Data([0x01, 0x42, 0x00, 0x1E, 0xFF, 0xE1, 0x00, 0x04, 0x67, 0x42, 0x00, 0x1E, 0x01, 0x00, 0x04, 0x68, 0x00, 0x00, 0x0D])
    
    // Initialize AVCDecoderConfigurationRecord
    let avcRecord = AVCDecoderConfigurationRecord(avcDecoderConfigurationRecord: mockData)
    
    // Validate
    XCTAssertNotNil(avcRecord)
    XCTAssertEqual(avcRecord?.configurationVersion, 1)
    XCTAssertEqual(avcRecord?.avcProfileIndication, 66)
    XCTAssertEqual(avcRecord?.profileCompatibility, 0)
    XCTAssertEqual(avcRecord?.avcLevelIndication, 30)
    XCTAssertEqual(avcRecord?.lengthSizeMinusOne, 3)
    XCTAssertEqual(avcRecord?.ppsList.count, 1)
    XCTAssertEqual(avcRecord?.spsList.count, 1)
    XCTAssertEqual(avcRecord?.spsList.first, Data([103, 66, 0, 30]))
    XCTAssertEqual(avcRecord?.ppsList.first, Data([104, 0, 0, 13]))
  }
  
  func testInitWithInvalidData() {
    // Prepare an invalid mock AVCDecoderConfigurationRecord data
    let mockData: Data = Data([1, 66]) // Too short to be valid
    
    // Initialize AVCDecoderConfigurationRecord
    let avcRecord = AVCDecoderConfigurationRecord(avcDecoderConfigurationRecord: mockData)
    
    // Validate
    XCTAssertNil(avcRecord)
  }
  
  func testInitWithSPSAndPPS() {
    // Prepare mock SPS and PPS data
    let sps: Data = Data([103, 66, 0, 30])
    let pps: Data = Data([104, 0, 0, 13])
    
    // Initialize AVCDecoderConfigurationRecord
    let avcRecord = AVCDecoderConfigurationRecord(sps: sps, pps: pps)
    
    // Validate
    XCTAssertNotNil(avcRecord)
    XCTAssertEqual(avcRecord.configurationVersion, 1)
    XCTAssertEqual(avcRecord.avcProfileIndication, 66)
    XCTAssertEqual(avcRecord.profileCompatibility, 0)
    XCTAssertEqual(avcRecord.avcLevelIndication, 30)
    XCTAssertEqual(avcRecord.lengthSizeMinusOne, 3)
    XCTAssertEqual(avcRecord.ppsList.count, 1)
    XCTAssertEqual(avcRecord.spsList.count, 1)
    XCTAssertEqual(avcRecord.spsList.first, sps)
    XCTAssertEqual(avcRecord.ppsList.first, pps)
  }
  
  func testGenerateConfigurationRecord() {
    // Prepare mock SPS and PPS data
    let sps: Data = Data([103, 66, 0, 30])
    let pps: Data = Data([104, 0, 0, 13])
    
    // Initialize AVCDecoderConfigurationRecord
    let avcRecord = AVCDecoderConfigurationRecord(sps: sps, pps: pps)
    
    // Generate Configuration Record
    let generatedData = avcRecord.generateConfigurationRecord()
    
    // Validate
    // The expected data would depend on how you've implemented generateConfigurationRecord
    // For this example, let's assume it concatenates all the fields and SPS/PPS data
    var expectedData = Data()
    expectedData.append(1)  // configurationVersion
    expectedData.append(sps[1])  // avcProfileIndication
    expectedData.append(sps[2])  // profileCompatibility
    expectedData.append(sps[3])  // avcLevelIndication
    expectedData.append(0xFF)  // 6 bits reserved (111111) + 2 bits lengthSizeMinusOne (11)
    expectedData.append(0xE1)  // 3 bits reserved (111) + 5 bits numOfSPS (00001)
    
    // SPS
    let spsLengthData = UInt16(sps.count).bigEndian.data
    expectedData.append(spsLengthData)
    expectedData.append(sps)
    
    // PPS
    expectedData.append(1)  // numOfPPS
    let ppsLengthData = UInt16(pps.count).bigEndian.data
    expectedData.append(ppsLengthData)
    expectedData.append(pps)

    XCTAssertEqual(generatedData, expectedData)
  }
}
