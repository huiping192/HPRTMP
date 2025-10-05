import Foundation

actor ChunkDecoder {

  // MARK: - State Machine

  private enum State {
    case waitingBasicHeader
    case waitingMessageHeader(basicHeader: BasicHeader, basicHeaderSize: Int)
    case waitingExtendedTimestamp(basicHeader: BasicHeader, messageHeader: any MessageHeader, headerSize: Int)
    case waitingPayload(chunkHeader: ChunkHeader, headerSize: Int, payloadLength: Int)
  }
  
  private enum ProcessResult {
    case chunk(Chunk)
    case needMoreData
    case continueProcessing
  }

  // MARK: - Stream Context

  struct StreamContext {
    var messageLength: Int
    var messageType: MessageType
    var messageStreamId: Int
    var timestamp: UInt32
    var remainingLength: Int  // Remaining bytes to read for current message
  }

  // MARK: - Properties

  private var buffer = Data()
  private var state: State = .waitingBasicHeader
  private(set) var streamContexts: [UInt16: StreamContext] = [:]
  var maxChunkSize: Int = 128
  private let maxTimestamp: UInt32 = 16777215

  // MARK: - Public API

  func setMaxChunkSize(maxChunkSize: Int) {
    self.maxChunkSize = maxChunkSize
  }

  func append(_ data: Data) {
    buffer.append(data)
  }

  var hasBufferedData: Bool {
    !buffer.isEmpty
  }

  func reset() {
    buffer = Data()
    state = .waitingBasicHeader
    streamContexts = [:]
  }

  /// Decode a chunk from buffered data
  /// - Returns: Optional tuple of (Chunk?, bytes consumed).
  ///   - nil: need more data
  ///   - (nil, 0): decode error
  ///   - (Chunk, size): success
  func decodeChunk() -> Chunk? {
    switch state {
    case .waitingBasicHeader:
      return tryDecodeBasicHeader()

    case .waitingMessageHeader(let basicHeader, let basicHeaderSize):
      return tryDecodeMessageHeader(basicHeader: basicHeader, basicHeaderSize: basicHeaderSize)

    case .waitingExtendedTimestamp(let basicHeader, let messageHeader, let headerSize):
      return tryDecodeExtendedTimestamp(basicHeader: basicHeader, messageHeader: messageHeader, headerSize: headerSize)

    case .waitingPayload(let chunkHeader, let headerSize, let payloadLength):
      return tryDecodePayload(chunkHeader: chunkHeader, headerSize: headerSize, payloadLength: payloadLength)
    }
  }

  // MARK: - State Transition Methods

  private func tryDecodeBasicHeader() -> Chunk? {
    guard let byte = buffer.first else {
      return nil // Need more data
    }

    // Parse format (first 2 bits)
    let fmt = byte >> 6
    guard let headerType = MessageHeaderType(rawValue: fmt) else {
      return nil // Invalid format
    }

    // Parse chunk stream ID
    let compare: UInt8 = 0b00111111
    let streamId: UInt16
    let basicHeaderLength: Int

    switch compare & byte {
    case 0:
      guard buffer.count >= 2 else { return nil }
      basicHeaderLength = 2
      let startIndex = buffer.startIndex
      streamId = UInt16(buffer[startIndex + 1] + 64)

    case 1:
      guard buffer.count >= 3 else { return nil }
      basicHeaderLength = 3
      let startIndex = buffer.startIndex
      streamId = UInt16(Data(buffer[startIndex + 1...startIndex + 2].reversed()).uint16) + 64

    default:
      basicHeaderLength = 1
      streamId = UInt16(compare & byte)
    }

    let basicHeader = BasicHeader(streamId: streamId, type: headerType)

    // Transition to next state
    state = .waitingMessageHeader(basicHeader: basicHeader, basicHeaderSize: basicHeaderLength)
    buffer.removeFirst(basicHeaderLength)

    // Continue decoding
    return decodeChunk()
  }

  private func tryDecodeMessageHeader(basicHeader: BasicHeader, basicHeaderSize: Int) -> Chunk? {
    let headerData = buffer
    let messageHeader: (any MessageHeader)?
    let messageHeaderSize: Int

    switch basicHeader.type {
    case .type0:
      guard headerData.count >= 11 else { return nil }
      let startIndex = headerData.startIndex
      let timestamp = Data(headerData[startIndex...startIndex+2].reversed() + [0x00]).uint32
      let messageLength = Data(headerData[startIndex+3...startIndex+5].reversed() + [0x00]).uint32
      let messageType = MessageType(rawValue: headerData[startIndex+6])
      let messageStreamId = Data(headerData[startIndex+7...startIndex+10]).uint32

      // Check for extended timestamp
      if timestamp == maxTimestamp {
        messageHeader = MessageHeaderType0(timestamp: 0, messageLength: Int(messageLength), type: messageType, messageStreamId: Int(messageStreamId))
        messageHeaderSize = 11
        state = .waitingExtendedTimestamp(basicHeader: basicHeader, messageHeader: messageHeader!, headerSize: basicHeaderSize + messageHeaderSize)
        buffer.removeFirst(messageHeaderSize)
        return decodeChunk()
      }

      messageHeader = MessageHeaderType0(timestamp: timestamp, messageLength: Int(messageLength), type: messageType, messageStreamId: Int(messageStreamId))
      messageHeaderSize = 11

      // Update stream context for Type0
      streamContexts[basicHeader.streamId] = StreamContext(
        messageLength: Int(messageLength),
        messageType: messageType,
        messageStreamId: Int(messageStreamId),
        timestamp: timestamp,
        remainingLength: Int(messageLength)
      )

    case .type1:
      guard headerData.count >= 7 else { return nil }
      let startIndex = headerData.startIndex
      let timestampDelta = Data(headerData[startIndex...startIndex+2].reversed() + [0x00]).uint32
      let messageLength = Data(headerData[startIndex+3...startIndex+5].reversed() + [0x00]).uint32
      let messageType = MessageType(rawValue: headerData[startIndex+6])

      messageHeader = MessageHeaderType1(timestampDelta: timestampDelta, messageLength: Int(messageLength), type: messageType)
      messageHeaderSize = 7

      // Update stream context for Type1 (reuse messageStreamId from context)
      if var context = streamContexts[basicHeader.streamId] {
        context.messageLength = Int(messageLength)
        context.messageType = messageType
        context.timestamp += timestampDelta
        context.remainingLength = Int(messageLength)
        streamContexts[basicHeader.streamId] = context
      } else {
        // Create new context if none exists (not strictly RTMP compliant, but allows testing)
        streamContexts[basicHeader.streamId] = StreamContext(
          messageLength: Int(messageLength),
          messageType: messageType,
          messageStreamId: 0,  // Unknown for Type1 without prior context
          timestamp: timestampDelta,
          remainingLength: Int(messageLength)
        )
      }

    case .type2:
      guard headerData.count >= 3 else { return nil }
      let startIndex = headerData.startIndex
      let timestampDelta = Data(headerData[startIndex...startIndex+2].reversed() + [0x00]).uint32

      messageHeader = MessageHeaderType2(timestampDelta: timestampDelta)
      messageHeaderSize = 3

      // Update stream context for Type2 (reuse messageLength, messageType, messageStreamId)
      if var context = streamContexts[basicHeader.streamId] {
        context.timestamp += timestampDelta
        // Type2 can continue an ongoing message OR start a new one
        // This is handled in getPayloadLength
        streamContexts[basicHeader.streamId] = context
      }

    case .type3:
      messageHeader = MessageHeaderType3()
      messageHeaderSize = 0
      // Type3: reuse all fields from previous chunk
    }

    guard let messageHeader = messageHeader else {
      return nil
    }

    // Calculate payload length
    let payloadLength = getPayloadLength(for: basicHeader.streamId, messageHeader: messageHeader)

    let chunkHeader = ChunkHeader(basicHeader: basicHeader, messageHeader: messageHeader)
    state = .waitingPayload(chunkHeader: chunkHeader, headerSize: basicHeaderSize + messageHeaderSize, payloadLength: payloadLength)
    buffer.removeFirst(messageHeaderSize)

    return decodeChunk()
  }

  private func tryDecodeExtendedTimestamp(basicHeader: BasicHeader, messageHeader: any MessageHeader, headerSize: Int) -> Chunk? {
    guard buffer.count >= 4 else { return nil }

    let startIndex = buffer.startIndex
    let extendedTimestamp = Data(buffer[startIndex...startIndex+3].reversed()).uint32
    buffer.removeFirst(4)

    // Update message header with extended timestamp
    let updatedMessageHeader: any MessageHeader
    if let header0 = messageHeader as? MessageHeaderType0 {
      updatedMessageHeader = MessageHeaderType0(
        timestamp: extendedTimestamp,
        messageLength: header0.messageLength,
        type: header0.type,
        messageStreamId: header0.messageStreamId
      )

      // Update stream context
      streamContexts[basicHeader.streamId] = StreamContext(
        messageLength: header0.messageLength,
        messageType: header0.type,
        messageStreamId: header0.messageStreamId,
        timestamp: extendedTimestamp,
        remainingLength: header0.messageLength
      )
    } else {
      updatedMessageHeader = messageHeader
    }

    let payloadLength = getPayloadLength(for: basicHeader.streamId, messageHeader: updatedMessageHeader)
    let chunkHeader = ChunkHeader(basicHeader: basicHeader, messageHeader: updatedMessageHeader)

    state = .waitingPayload(chunkHeader: chunkHeader, headerSize: headerSize + 4, payloadLength: payloadLength)

    return decodeChunk()
  }

  private func tryDecodePayload(chunkHeader: ChunkHeader, headerSize: Int, payloadLength: Int) -> Chunk? {
    guard buffer.count >= payloadLength else { return nil }

    let chunkData = buffer.prefix(payloadLength)
    buffer.removeFirst(payloadLength)

    // Update remaining length in stream context
    let streamId = chunkHeader.basicHeader.streamId
    if var context = streamContexts[streamId] {
      context.remainingLength -= payloadLength

      // If message is complete, we could clear the context, but we keep it
      // for the next message on the same stream (RTMP reuses contexts)
      if context.remainingLength <= 0 {
        // Message complete, reset remaining length for next message
        context.remainingLength = 0
      }
      streamContexts[streamId] = context
    }

    // Reset state for next chunk
    state = .waitingBasicHeader

    return Chunk(chunkHeader: chunkHeader, chunkData: Data(chunkData))
  }

  // MARK: - Helper Methods

  private func getPayloadLength(for streamId: UInt16, messageHeader: any MessageHeader) -> Int {
    // For Type0 and Type1, we can get length directly from header
    if let header0 = messageHeader as? MessageHeaderType0 {
      return min(header0.messageLength, maxChunkSize)
    }

    if let header1 = messageHeader as? MessageHeaderType1 {
      return min(header1.messageLength, maxChunkSize)
    }

    // For Type2 and Type3, we need context
    guard let context = streamContexts[streamId] else {
      return 0 // Error: no context available for Type2/3
    }

    // If remainingLength is 0, this is a new message with same parameters
    let length = context.remainingLength > 0 ? context.remainingLength : context.messageLength
    return min(length, maxChunkSize)
  }
}
