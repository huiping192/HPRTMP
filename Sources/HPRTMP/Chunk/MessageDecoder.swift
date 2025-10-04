import Foundation
import os

actor MessageDecoder {
  private var data = Data()
  
  private let chunkDecoder = ChunkDecoder()
  
  private var maxChunkSize: Int = Int(128)
  
  private(set) var isDecoding = false
  
  private let logger = Logger(subsystem: "HPRTMP", category: "MessageDecoder")
  
  // for header type2 decode
  private var lastChunk: Chunk?
  
  func setMaxChunkSize(maxChunkSize: Int) async {
    self.maxChunkSize = maxChunkSize
    await chunkDecoder.setMaxChunkSize(maxChunkSize: maxChunkSize)
  }
  
  func append(_ newData: Data) {
    self.data.append(newData)
  }
  
  var remainDataCount: Int {
    data.count
  }
  
  func decode() async -> RTMPMessage? {
    guard !isDecoding else { return nil }
    logger.debug("decode message start")
    isDecoding = true
    let (message,size) = await decodeMessage(data: data)
    guard let message else { return nil }
    data.removeFirst(size)
    isDecoding = false
    logger.debug("MessageDecoder remain data count: \(self.data.count)")
    return message
  }
  
  func reset() {
    data = Data()
    isDecoding = false
  }
  
  func createMessage(chunkStreamId: UInt16, msgStreamId: Int, messageType: MessageType, timestamp: UInt32, chunkPayload: Data) -> RTMPMessage? {
    switch messageType {
    case .chunkSize:
      let size = Data(chunkPayload.reversed()).uint32
      return ChunkSizeMessage(size: size)
    case .control:
      return ControlMessage(type: messageType)
    case .peerBandwidth:
      guard let windowAckSize = chunkPayload[safe: 0..<4]?.reversed() else {
        return nil
      }
      let peer = Data(windowAckSize).uint32
      return PeerBandwidthMessage(windowSize: peer, limit: .dynamic)
    case .command(type: let type):
      let data = type == .amf0 ? chunkPayload.decodeAMF0() : chunkPayload.decodeAMF3()

      // first is command name
      guard let commandName = data?.first?.stringValue else { return nil }

      // second is Transaction ID, number
      let transactionId = data?[safe: 1]?.doubleValue

      // third is command object
      let commandObject = data?[safe: 2]?.objectValue

      // fourth is info, maybe object([String: Any?]) or Number(connect messsage)
      let info = data?[safe: 3]

      return CommandMessage(encodeType: type, commandName: commandName, transactionId: Int(transactionId ?? 0), commandObject: commandObject, info: info, msgStreamId: msgStreamId, timestamp: timestamp)
    case .data(type: let type):
      return AnyDataMessage(encodeType: type, msgStreamId: msgStreamId)
    case .share(type: let type):
      let data = type == .amf0 ? chunkPayload.decodeAMF0() : chunkPayload.decodeAMF3()
      // First is "onSharedObject", second is name, third is object
      let sharedObjectName = data?[safe: 1]?.stringValue
      let sharedObject = data?[safe: 2]?.objectValue
      return SharedObjectMessage(encodeType: type, msgStreamId: msgStreamId, sharedObjectName: sharedObjectName, sharedObject: sharedObject)
    case .audio:
      return AudioMessage(data: chunkPayload, msgStreamId: msgStreamId, timestamp: timestamp)
    case .video:
      return VideoMessage(data: chunkPayload, msgStreamId: msgStreamId, timestamp: timestamp)
    case .aggreate:
      return nil
    case .abort:
      return AbortMessage(chunkStreamId: chunkStreamId)
    case .acknowledgement:
      let size = Data(chunkPayload.reversed()).uint32
      return AcknowledgementMessage(sequence: size)
    case .windowAcknowledgement:
      guard let windowAckSize = chunkPayload[safe: 0..<4]?.reversed() else {
        return nil
      }
      let size = Data(windowAckSize).uint32
      return WindowAckMessage(size: size)
    case .none:
      return nil
    }
  }
  
  func decodeMessage(data: Data) async -> (RTMPMessage?,Int) {
    let (firstChunk, chunkSize) = await chunkDecoder.decodeChunk(data: data)
    guard let firstChunk = firstChunk else {
      return (nil,0)
    }
    
    if let messageHeaderType0 = firstChunk.chunkHeader.messageHeader as? MessageHeaderType0 {
      previousChunkMessageId = messageHeaderType0.messageStreamId
      lastChunk = firstChunk
      return await handleMessageHeaderType0(firstChunk: firstChunk, chunkSize: chunkSize, messageHeaderType0: messageHeaderType0, data: data)
    }
    
    if let messageHeaderType1 = firstChunk.chunkHeader.messageHeader as? MessageHeaderType1 {
      let (message,size) = await handleMessageHeaderType1(firstChunk: firstChunk, chunkSize: chunkSize, messageHeaderType1: messageHeaderType1)
      lastChunk = firstChunk
      previousChunkMessageId = message?.msgStreamId
      return (message,size)
    }
    
    if let messageHeaderType2 = firstChunk.chunkHeader.messageHeader as? MessageHeaderType2 {
        let (message,size) = await handleMessageHeaderType2(firstChunk: firstChunk, chunkSize: chunkSize, messageHeaderType2: messageHeaderType2)
        previousChunkMessageId = message?.msgStreamId
        return (message,size)
    }

    return (nil,0)
  }
  
  private func handleMessageHeaderType2(firstChunk: Chunk, chunkSize: Int, messageHeaderType2: MessageHeaderType2) async -> (RTMPMessage?,Int) {
    guard let lastChunk = lastChunk else {
      return (nil,0)
    }
    
    var chunkStreamId: UInt16 = 0
    var messageLength: Int = 0
    var msgStreamId: Int = 0
    var messageType: MessageType!
    let timestamp = messageHeaderType2.timestampDelta
    
    if let lastMessageHeader = lastChunk.chunkHeader.messageHeader as? MessageHeaderType0 {
      chunkStreamId = lastChunk.chunkHeader.basicHeader.streamId
      messageLength = lastMessageHeader.messageLength
      msgStreamId = lastMessageHeader.messageStreamId
      messageType = lastMessageHeader.type
    }
    
    if let lastMessageHeader = lastChunk.chunkHeader.messageHeader as? MessageHeaderType1 {
      chunkStreamId = lastChunk.chunkHeader.basicHeader.streamId
      messageLength = lastMessageHeader.messageLength
      msgStreamId = previousChunkMessageId!
      messageType = lastMessageHeader.type
    }
    
    // one chunk = one message
    if messageLength <= maxChunkSize {
      let message = createMessage(chunkStreamId: chunkStreamId,
                                  msgStreamId: msgStreamId,
                                  messageType: messageType,
                                  timestamp: timestamp,
                                  chunkPayload: lastChunk.chunkData)
      return (message,chunkSize)
    }
    
    // has multiple chunks
    var remainPayloadSize = messageLength - maxChunkSize
    var totalPayload = lastChunk.chunkData
    var allChunkSize = chunkSize
    while remainPayloadSize > 0 {
      let (chunk, chunkSize) = await chunkDecoder.decodeChunk(data: data.advanced(by: allChunkSize))
      guard let chunk else { return (nil,0) }
      remainPayloadSize -= chunk.chunkData.count
      totalPayload.append(chunk.chunkData)
      allChunkSize += chunkSize
    }
    
    let message = createMessage(chunkStreamId: firstChunk.chunkHeader.basicHeader.streamId,
                                msgStreamId: msgStreamId,
                                messageType: messageType,
                                timestamp: timestamp,
                                chunkPayload: totalPayload)
    return (message,allChunkSize)
  }
  
  
  private func handleMessageHeaderType0(firstChunk: Chunk, chunkSize: Int, messageHeaderType0: MessageHeaderType0, data: Data) async -> (RTMPMessage?,Int) {
    let messageLength = messageHeaderType0.messageLength
    // one chunk = one message
    if messageLength <= maxChunkSize {
      let message = createMessage(chunkStreamId: firstChunk.chunkHeader.basicHeader.streamId,
                                  msgStreamId: messageHeaderType0.messageStreamId,
                                  messageType: messageHeaderType0.type,
                                  timestamp: messageHeaderType0.timestamp,
                                  chunkPayload: firstChunk.chunkData)
      return (message,chunkSize)
    }
    
    // has multiple chunks
    var remainPayloadSize = messageLength - maxChunkSize
    var totalPayload = firstChunk.chunkData
    var allChunkSize = chunkSize
    while remainPayloadSize > 0 {
      let (chunk, chunkSize) = await chunkDecoder.decodeChunk(data: data.advanced(by: chunkSize))
      guard let chunk else { return (nil,0) }
      
      // same stream id chunk
      guard chunk.chunkHeader.basicHeader.streamId == firstChunk.chunkHeader.basicHeader.streamId else {
        continue
      }
      totalPayload.append(chunk.chunkData)
      allChunkSize += chunkSize
      remainPayloadSize -= chunk.chunkData.count
    }
    let message = createMessage(chunkStreamId: firstChunk.chunkHeader.basicHeader.streamId,
                                msgStreamId: messageHeaderType0.messageStreamId,
                                messageType: messageHeaderType0.type,
                                timestamp: messageHeaderType0.timestamp,
                                chunkPayload: totalPayload)
    return (message, allChunkSize)
  }
  
  private var previousChunkMessageId: Int?
  
  private func handleMessageHeaderType1(firstChunk: Chunk, chunkSize: Int, messageHeaderType1: MessageHeaderType1) async -> (RTMPMessage?,Int) {
    guard let previousChunkMessageId = previousChunkMessageId else { return (nil,0) }

    let messageLength = messageHeaderType1.messageLength

    // one chunk = one message
    if messageLength <= maxChunkSize {
      let message = createMessage(chunkStreamId: firstChunk.chunkHeader.basicHeader.streamId,
                                  msgStreamId: previousChunkMessageId,
                                  messageType: messageHeaderType1.type,
                                  timestamp: messageHeaderType1.timestampDelta,
                                  chunkPayload: firstChunk.chunkData)
      return (message,chunkSize)
    }
    
    var remainPayloadSize = messageLength - maxChunkSize
    var totalPayload = firstChunk.chunkData
    var allChunkSize = chunkSize
    while remainPayloadSize > 0 {
      let (chunk, chunkSize) = await chunkDecoder.decodeChunk(data: data.advanced(by: chunkSize))
      guard let chunk else { return (nil,0) }
      
      // same stream id chunk
      guard chunk.chunkHeader.basicHeader.streamId == firstChunk.chunkHeader.basicHeader.streamId else {
        continue
      }
      totalPayload.append(chunk.chunkData)
      allChunkSize += chunkSize
      remainPayloadSize -= chunk.chunkData.count
    }
    let message = createMessage(chunkStreamId: firstChunk.chunkHeader.basicHeader.streamId,
                                msgStreamId: previousChunkMessageId,
                                messageType: messageHeaderType1.type,
                                timestamp: messageHeaderType1.timestampDelta,
                                chunkPayload: totalPayload)
    return (message, allChunkSize)
  }
}
