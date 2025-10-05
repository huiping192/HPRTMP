import Foundation

actor MessageEncoder {
  
  static let maxChunkSize: UInt32 = 128
  
  private var chunkSize = UInt32(MessageEncoder.maxChunkSize)

  func setChunkSize(chunkSize: UInt32) {
    self.chunkSize = chunkSize
  }
  
  func encode(message: RTMPMessage, isFirstType0: Bool) -> [Chunk] {
    let payload = message.payload
    let payloadChunks = payload.split(size: Int(chunkSize))
    
    return payloadChunks.enumerated().map { chunkIndex, chunkData in
      let messageHeader = createMessageHeader(
        for: message,
        isFirstChunk: chunkIndex == 0,
        useType0: isFirstType0
      )
      
      let header = ChunkHeader(streamId: message.streamId, messageHeader: messageHeader)
      return Chunk(chunkHeader: header, chunkData: chunkData)
    }
  }
  
  private func createMessageHeader(for message: RTMPMessage, isFirstChunk: Bool, useType0: Bool) -> MessageHeader {
    guard isFirstChunk else {
      // Subsequent chunks use Type3 (no header information, reuse previous)
      return MessageHeaderType3()
    }
    
    if useType0 {
      // Type0: Full message header with absolute timestamp
      return MessageHeaderType0(
        timestamp: message.timestamp,
        messageLength: message.payload.count,
        type: message.messageType,
        messageStreamId: message.msgStreamId
      )
    } else {
      // Type1: Message header without message stream ID (uses timestamp delta)
      return MessageHeaderType1(
        timestampDelta: message.timestamp,
        messageLength: message.payload.count,
        type: message.messageType
      )
    }
  }
}


