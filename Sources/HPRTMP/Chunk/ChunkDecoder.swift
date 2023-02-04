//
//  File.swift
//  
//
//  Created by Huiping Guo on 2023/02/04.
//

import Foundation

enum RTMPMessageDecodeStatus {
    case payload(data: Data, isChunk: Bool)
    case notEnoughData
    case error(desc: String)
}

class ChunkDecoder {
  private let queue = DispatchQueue(label: "com.huiping192.hprtmp.chunkDecoder")
  
  // chunk size 128
  private static let maxChunkSize: UInt8 = 128
  var chunkSize: UInt32 = UInt32(ChunkDecoder.maxChunkSize)
  var preLength: UInt32 = 0
  var map = [Int: ChunkHeader]()
  var chunkBlock:((ChunkHeader)->Void)?

  private var isStart = false
  private var decodeData = Data() {
      didSet {
          if decodeData.count == 0 {
              self.isStart = false
          } else if !isStart {
              
              if isStart {
                  return
              }
              
              self.isStart = true
              self.innerDecode()
          }
      }
  }
  
  func decode(data: Data, chunk:((_ data: ChunkHeader)->Void)?) {

    
  }
  
  private func innerDecode() {
    queue.async { [weak self] in
      self?.decodeIfNeeded()
    }
  }
  
  private func decodeIfNeeded() {
    guard let first = decodeData.first else {
      self.isStart = false
      return
    }
    
    let type = Int(first >> 6)
    let compare: UInt8 = 0b00111111
    var streamId: Int = 0
    var basicHeaderSize = 0
    switch compare & first {
    case 0:
        basicHeaderSize = 2
        streamId = Int(decodeData[1] + 64)
    case 1:
        basicHeaderSize = 3
        streamId = Int(Data(decodeData[1...2].reversed()).uint16)
    default:
        basicHeaderSize = 1
        streamId = Int(compare & first)
    }
    var rc:RTMPMessageDecodeStatus = .error(desc: "Empty")
    switch type {
    case 0:
        rc = self.decodeType0(streamId: Int(streamId), basicHeaderSize: basicHeaderSize)
    case 1:
        rc = self.decodeType1(streamId: Int(streamId), basicHeaderSize: basicHeaderSize)
    case 2:
        rc = self.decodeType2(streamId: Int(streamId), basicHeaderSize: basicHeaderSize)
    case 3:
        rc = self.decodeType3(streamId: Int(streamId), basicHeaderSize: basicHeaderSize)
    default: break
    }
    if self.decodeData.count > 0 {
        switch rc {
        case .notEnoughData:
            self.isStart = false
        case .payload(_,_):
            self.decodeIfNeeded()
        case .error(let desc):
            print("Error Stop:\(desc)")
        }
    } else {
        self.isStart = false
    }
  }
  
  func decodeType0(streamId: Int, basicHeaderSize: Int) -> RTMPMessageDecodeStatus {
    guard let dataTime = self.decodeData[safe: (0...2).shift(index: basicHeaderSize)],
          let dataLength = self.decodeData[safe:(3...5).shift(index: basicHeaderSize)] else {
        return .notEnoughData
    }
    
    var time = Data(dataTime.reversed()).uint32
    
    let isExtendTime = (Double(time) == maxTimestamp)
    let headerSize = isExtendTime ? 15 : 11
    if isExtendTime {
        guard let dataExtend = self.decodeData[safe: (11...14).shift(index: basicHeaderSize)] else {
            return .notEnoughData
        }
        time = Data(dataExtend.reversed()).uint32
    }
    
    preLength = Data(dataLength.reversed()).uint32
    
    switch self.decodePayload(length: preLength, headerSize: headerSize+basicHeaderSize) {
    case .payload(let data, let isChunk):
        let type = MessageType(rawValue: Data([self.decodeData[6+basicHeaderSize]]).uint8)
        let msgStreamId = Data(self.decodeData[(7...10).shift(index: basicHeaderSize)].reversed()).uint32
        
        let header0 = MessageHeaderType0(timestamp: TimeInterval(time),
                                         messageLength: Int(preLength),
                                         type: type,
                                         messageStreamId: Int(msgStreamId))

        let header =  ChunkHeader(streamId: Int(streamId),
                                      messageHeader:
            header0,
                                      chunkPayload: Data(data))

        if isChunk {
            self.map[Int(streamId)] = header
        } else {
            chunkBlock?(header)
        }
        self.decodeData.removeSubrange(0..<headerSize+basicHeaderSize+data.count)
        return .payload(data: data, isChunk: isChunk)
    case .notEnoughData:
        return .notEnoughData
    case .error(let desc):
        return .error(desc: desc)
    }
  }

  func decodeType1(streamId: Int, basicHeaderSize: Int) -> RTMPMessageDecodeStatus {
    return .error(desc: "desc")
  }
  func decodeType2(streamId: Int, basicHeaderSize: Int) -> RTMPMessageDecodeStatus {
    return .error(desc: "desc")
  }
  func decodeType3(streamId: Int, basicHeaderSize: Int) -> RTMPMessageDecodeStatus {
    return .error(desc: "desc")
  }

  func reset() {
    
  }
  
  private func decodePayload(length: UInt32, headerSize: Int) -> RTMPMessageDecodeStatus {
      var payloadRange = 0..<Int(length)
      let isChunk = length > self.chunkSize
      if isChunk {
          payloadRange = 0..<Int(self.chunkSize)
      }
      if let data = decodeData[safe: payloadRange.shift(index: headerSize)] {
          return .payload(data: data, isChunk: isChunk)
      } else {
          return .notEnoughData
      }
  }
}
