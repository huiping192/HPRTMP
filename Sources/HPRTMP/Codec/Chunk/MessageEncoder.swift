import Foundation

actor MessageEncoder {
  
  private static let defaultChunkSize: UInt32 = 128
  static let minChunkSize: UInt32 = 1
  static let maxChunkSize: UInt32 = 0xFFFFFF  // RTMP spec max: 16777215
  
  private var chunkSize = UInt32(MessageEncoder.defaultChunkSize)

  // Track last message state for Type2 header optimization
  private var lastMessageLength: Int?
  private var lastMessageType: MessageType?
  private var lastMessageStreamId: MessageStreamId?

  // Track last timestamps for delta calculation by message type
  private var lastTimestamps: [MessageType: Timestamp] = [:]
  
  func setChunkSize(chunkSize: UInt32) throws {
    guard chunkSize >= Self.minChunkSize && chunkSize <= Self.maxChunkSize else {
      throw RTMPError.invalidChunkSize(size: chunkSize, min: Self.minChunkSize, max: Self.maxChunkSize)
    }
    self.chunkSize = chunkSize
  }

  /// Reset encoder state (useful when reusing encoder or starting new stream)
  func reset() {
    lastMessageLength = nil
    lastMessageType = nil
    lastMessageStreamId = nil
    lastTimestamps.removeAll()
  }
  
  func encode(message: RTMPMessage, isFirstType0: Bool) -> [Chunk] {
    let payload = message.payload
    let payloadChunks = payload.split(size: Int(chunkSize))

    let chunks = payloadChunks.enumerated().map { chunkIndex, chunkData in
      let messageHeader = createMessageHeader(
        for: message,
        isFirstChunk: chunkIndex == 0,
        useType0: isFirstType0
      )

      let header = ChunkHeader(streamId: message.streamId, messageHeader: messageHeader)
      return Chunk(chunkHeader: header, chunkData: chunkData)
    }

    // Update state for next message
    lastMessageLength = message.payload.count
    lastMessageType = message.messageType
    lastMessageStreamId = message.msgStreamId
    lastTimestamps[message.messageType] = message.timestamp

    return chunks
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
    }

    // Calculate timestamp delta based on last timestamp of same message type
    let timestampDelta: Timestamp
    if let lastTimestamp = lastTimestamps[message.messageType] {
      timestampDelta = message.timestamp - lastTimestamp
    } else {
      timestampDelta = message.timestamp
    }

    // Check if we can use Type2 (only timestamp delta, same length/type/streamId)
    if let lastLength = lastMessageLength,
       let lastType = lastMessageType,
       let lastStreamId = lastMessageStreamId,
       lastLength == message.payload.count,
       lastType == message.messageType,
       lastStreamId == message.msgStreamId {
      // Type2: Only timestamp delta (3 bytes)
      return MessageHeaderType2(timestampDelta: timestampDelta)
    }

    // Type1: Timestamp delta + length + type (7 bytes)
    return MessageHeaderType1(
      timestampDelta: timestampDelta,
      messageLength: message.payload.count,
      type: message.messageType
    )
  }
}


