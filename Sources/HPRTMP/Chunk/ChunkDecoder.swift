//
//  File.swift
//  
//
//  Created by Huiping Guo on 2023/02/04.
//

import Foundation

class MessageDecoder {
  func append(_ data: Data) {
    
  }
  
  func decode() -> RTMPBaseMessageProtocol? {
    return nil
  }
}


actor ChunkDecoder {
  
  var data = Data()
  
  func append(_ data: Data) {
    
  }
  
  func decode() -> RTMPBaseMessageProtocol? {
    return nil
  }
  
//  func decode() -> [Chunk] {
//    // basic
//
//    return []
//  }
  
  private static let maxChunkSize: UInt8 = 128
  var chunkSize: Int = Int(ChunkDecoder.maxChunkSize)
  
  private var chunks: [Chunk] = []
  
  private var messageDataLengthMap: [UInt16: Int] = [:]
  private var remainDataLengthMap: [UInt16: Int] = [:]
  
  
  func reset() {
    chunks = []
    messageDataLengthMap = [:]
    remainDataLengthMap = [:]
  }
  
  private func getChunkDataLength(streamId: UInt16) -> Int? {
    // every chunk is same data size
    if let messageDataLength = messageDataLengthMap[streamId]  {
      return messageDataLength
    }

    // big data size
    guard let remainDataLength = remainDataLengthMap[streamId] else { return nil }
    if remainDataLength > chunkSize {
      remainDataLengthMap[streamId] = remainDataLength - chunkSize
      return chunkSize
    }
    remainDataLengthMap.removeValue(forKey: streamId)
    return remainDataLength
  }
  
  func decode() -> (Chunk?, Int) {
    let (basicHeader, basicHeaderSize) = decodeBasicHeader(data: data)
    guard let basicHeader else { return (nil,0) }
    
    let (messageHeader, messageHeaderSize) = decodeMessageHeader(data: data.advanced(by: basicHeaderSize), type: basicHeader.type)
    guard let messageHeader else { return (nil,0) }

    if let messageHeaderType0 = messageHeader as? MessageHeaderType0 {
      let messageLength = messageHeaderType0.messageLength
      let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: messageHeaderSize), messageLength: messageLength)
      guard let chunkData else {
        return (nil,0)
      }
      
      if messageLength <= chunkSize {
        messageDataLengthMap[basicHeader.streamId] = messageLength
      } else {
        remainDataLengthMap[basicHeader.streamId] = messageLength - chunkSize
      }
      
      let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
      return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
    }
    
    if let messageHeaderType1 = messageHeader as? MessageHeaderType1 {
      let messageLength = messageHeaderType1.messageLength
      let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: messageHeaderSize), messageLength: messageLength)
      guard let chunkData else {
        return (nil,0)
      }
      
      if messageLength <= chunkSize {
        messageDataLengthMap[basicHeader.streamId] = messageLength
      } else {
        remainDataLengthMap[basicHeader.streamId] = messageLength - chunkSize
      }
      let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
      return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
    }
    
    if let _ = messageHeader as? MessageHeaderType2 {
      guard let payloadLength = getChunkDataLength(streamId: basicHeader.streamId) else { return (nil,0) }
      let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: messageHeaderSize), messageLength: payloadLength)
      guard let chunkData else {
        return (nil,0)
      }
      
      let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
      return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
    }
    
    if let _ = messageHeader as? MessageHeaderType3 {
      guard let payloadLength = getChunkDataLength(streamId: basicHeader.streamId) else { return (nil,0) }
      let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: messageHeaderSize), messageLength: payloadLength)
      guard let chunkData else {
        return (nil,0)
      }
      
      let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
      return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
    }

    return (nil,0)
  }
  
  
  func decodeBasicHeader(data: Data) -> (BasicHeader?,Int) {
    guard let byte = data.first else {
      return (nil,0)
    }
    // first 2 bit is type
    let fmt = byte >> 6
    
    guard let headerType = MessageHeaderType(rawValue: Int(fmt)) else {
      return (nil,0)
    }
    
    let compare: UInt8 = 0b00111111
    let streamId: UInt16
    let basicHeaderLength: Int
    switch compare & byte {
    case 0:
      guard data.count >= 2 else { return (nil,0) }
      // 2bytes. fmt| 0 |csid-64
      basicHeaderLength = 2
      streamId = UInt16(data[1] + 64)
    case 1:
      guard data.count >= 3 else { return (nil,0) }
      // 3bytes. fmt|1| csid-64
      basicHeaderLength = 3
      streamId = UInt16(Data(data[1...2].reversed()).uint16) + 64
    default:
      // 1bytes, fmt| csid
      basicHeaderLength = 1
      streamId = UInt16(compare & byte)
    }
    
    return (BasicHeader(streamId: streamId, type: headerType), basicHeaderLength)
  }
  
  func decodeMessageHeader(data: Data, type: MessageHeaderType) -> ((any MessageHeader)?, Int) {
    switch type {
    case .type0:
      // 11bytes
      guard data.count >= 11 else { return (nil,0) }
      // timestamp 3bytes
      let timestamp = Data(data[0...2].reversed() + [0x00]).uint32
      // message length 3 byte
      let messageLength = Data(data[3...5].reversed() + [0x00]).uint32
      // message type id 1byte
      let messageType = MessageType(rawValue: data[6])
      // msg stream id 4bytes
      let messageStreamId = Data(data[7...10].reversed()).uint32
      
      if timestamp == maxTimestamp {
        let extendTimestamp = Data(data[11...14].reversed()).uint32
        return (MessageHeaderType0(timestamp: extendTimestamp, messageLength: Int(messageLength), type: messageType, messageStreamId: Int(messageStreamId)), 15)
      }
      
      return (MessageHeaderType0(timestamp: timestamp, messageLength: Int(messageLength), type: messageType, messageStreamId: Int(messageStreamId)), 11)
      
    case .type1:
      // 7bytes
      guard data.count >= 7 else { return (nil,0) }
      let timestampDelta = Data(data[0...2].reversed() + [0x00]).uint32
      let messageLength = Data(data[3...5].reversed() + [0x00]).uint32
      let messageType = MessageType(rawValue: data[6])
      
      return (MessageHeaderType1(timestampDelta: timestampDelta, messageLength: Int(messageLength), type: messageType),7)
      
    case .type2:
      // 3bytes
      guard data.count >= 3 else { return (nil,0) }
      let timestampDelta = Data(data[0...2].reversed() + [0x00]).uint32
      return (MessageHeaderType2(timestampDelta: timestampDelta), 3)
      
    case .type3:
      return (MessageHeaderType3(),0)
    }
  }
  
  func decodeChunkData(data: Data, messageLength: Int) -> (Data?, Int) {
    guard data.count >= messageLength else { return (nil,0) }
    let chunkData = data[0..<messageLength]
    return (chunkData, messageLength)
  }

}
