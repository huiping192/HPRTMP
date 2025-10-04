import Foundation

actor ChunkDecoder {
    
  private(set) var messageDataLengthMap: [UInt16: Int] = [:]
  private(set) var remainDataLengthMap: [UInt16: Int] = [:]
  
  var maxChunkSize: Int = Int(128)
  
  func setMaxChunkSize(maxChunkSize: Int) {
    self.maxChunkSize = maxChunkSize
  }
  
  func reset() {
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
    if remainDataLength > maxChunkSize {
      remainDataLengthMap[streamId] = remainDataLength - maxChunkSize
      return maxChunkSize
    }
    remainDataLengthMap.removeValue(forKey: streamId)
    return remainDataLength
  }
  
  
  
  func decodeChunk(data: Data) -> (Chunk?, Int) {
    // Decode basic header
    let (basicHeader, basicHeaderSize) = decodeBasicHeader(data: data)
    guard let basicHeader = basicHeader else { return (nil, 0) }
    
    // Decode message header
    let (messageHeader, messageHeaderSize) = decodeMessageHeader(data: data.advanced(by: basicHeaderSize), type: basicHeader.type)
    guard let messageHeader = messageHeader else { return (nil, 0) }
    
    // Check if message header is of type 0 or type 1, then process it
    if let messageHeaderType0 = messageHeader as? MessageHeaderType0 {
      return processMessageHeader(data: data, basicHeader: basicHeader, messageHeader: messageHeaderType0, basicHeaderSize: basicHeaderSize, messageHeaderSize: messageHeaderSize)
    }
    
    if let messageHeaderType1 = messageHeader as? MessageHeaderType1 {
      return processMessageHeader(data: data, basicHeader: basicHeader, messageHeader: messageHeaderType1, basicHeaderSize: basicHeaderSize, messageHeaderSize: messageHeaderSize)
    }
    
    // If message header is of type 2 or type 3, process it
    if messageHeader is MessageHeaderType2 || messageHeader is MessageHeaderType3 {
      guard let payloadLength = getChunkDataLength(streamId: basicHeader.streamId) else { return (nil, 0) }
      let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: basicHeaderSize + messageHeaderSize), messageLength: payloadLength)
      guard let chunkData = chunkData else {
        return (nil, 0)
      }
      let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
      return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
    }
    
    return (nil, 0)
  }
  
  func processMessageHeader(data: Data, basicHeader: BasicHeader, messageHeader: MessageHeader, basicHeaderSize: Int, messageHeaderSize: Int) -> (Chunk?, Int) {
    let messageLength: Int
    if let headerType0 = messageHeader as? MessageHeaderType0 {
      messageLength = headerType0.messageLength
    } else if let headerType1 = messageHeader as? MessageHeaderType1 {
      messageLength = headerType1.messageLength
    } else {
      return (nil, 0)
    }
    
    let currentMessageLength = messageLength <= maxChunkSize ? messageLength : maxChunkSize
    
    // Decode chunk data
    let (chunkData, chunkDataSize) = decodeChunkData(data: data.advanced(by: basicHeaderSize + messageHeaderSize), messageLength: currentMessageLength)
    guard let chunkData = chunkData else {
      return (nil, 0)
    }
    
    // Update message data length and remaining data length maps
    if messageLength <= maxChunkSize {
      messageDataLengthMap[basicHeader.streamId] = messageLength
    } else {
      remainDataLengthMap[basicHeader.streamId] = messageLength - maxChunkSize
    }
    
    let chunkSize = basicHeaderSize + messageHeaderSize + chunkDataSize
    return (Chunk(chunkHeader: ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader), chunkData: chunkData), chunkSize)
  }
  
  func decodeBasicHeader(data: Data) -> (BasicHeader?,Int) {
    guard let byte = data.first else {
      return (nil,0)
    }
    // first 2 bit is type
    let fmt = byte >> 6
    
    guard let headerType = MessageHeaderType(rawValue: fmt) else {
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
      // msg stream id 4bytes, little-endian
      let messageStreamId = Data(data[7...10]).uint32
      
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
