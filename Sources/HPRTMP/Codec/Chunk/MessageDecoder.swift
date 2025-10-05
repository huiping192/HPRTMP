import Foundation
import os

actor MessageDecoder {

  // MARK: - Assembling Message State

  private struct AssemblingMessage {
    let msgStreamId: MessageStreamId
    let messageType: MessageType
    let timestamp: Timestamp
    let totalLength: Int
    var accumulatedData: Data
  }

  // MARK: - Properties

  private let chunkDecoder = ChunkDecoder()
  private var maxChunkSize: Int = 128
  private(set) var isDecoding = false
  private let logger = Logger(subsystem: "HPRTMP", category: "MessageDecoder")
  private var assemblingMessages: [ChunkStreamId: AssemblingMessage] = [:]

  // MARK: - Public API

  func setMaxChunkSize(maxChunkSize: Int) async {
    self.maxChunkSize = maxChunkSize
    await chunkDecoder.setMaxChunkSize(maxChunkSize: maxChunkSize)
  }

  func append(_ newData: Data) async {
    await chunkDecoder.append(newData)
  }

  var remainDataCount: Int {
    get async {
      await chunkDecoder.hasBufferedData ? 1 : 0  // Simplified
    }
  }

  func decode() async -> RTMPMessage? {
    guard !isDecoding else { return nil }
    logger.debug("decode message start")
    isDecoding = true
    defer { isDecoding = false }

    let message = await decodeMessage()
    return message
  }

  func reset() async {
    await chunkDecoder.reset()
    assemblingMessages.removeAll()
    isDecoding = false
  }

  // MARK: - Message Decoding

  private func decodeMessage() async -> RTMPMessage? {
    // Try to decode chunks until we have a complete message
    while true {
      guard let chunk = await chunkDecoder.decodeChunk() else {
        // Need more data
        return nil
      }

      // Process the chunk based on current state
      if let message = await processChunk(chunk) {
        return message
      }
    }
  }

  private func processChunk(_ chunk: Chunk) async -> RTMPMessage? {
    let basicHeader = chunk.chunkHeader.basicHeader
    let messageHeader = chunk.chunkHeader.messageHeader
    let chunkStreamId = basicHeader.streamId

    // Determine message properties based on header type
    let msgStreamId: MessageStreamId
    let messageType: MessageType
    let timestamp: Timestamp
    let totalLength: Int

    if let header0 = messageHeader as? MessageHeaderType0 {
      msgStreamId = header0.messageStreamId
      messageType = header0.type
      timestamp = header0.timestamp
      totalLength = header0.messageLength

    } else if let header1 = messageHeader as? MessageHeaderType1 {
      messageType = header1.type
      totalLength = header1.messageLength
      timestamp = header1.timestampDelta

      // Get msgStreamId from stream context
      let context = await chunkDecoder.streamContexts[chunkStreamId]
      msgStreamId = context?.messageStreamId ?? MessageStreamId(0)

    } else if let header2 = messageHeader as? MessageHeaderType2 {
      timestamp = header2.timestampDelta

      // Get other fields from stream context
      let context = await chunkDecoder.streamContexts[chunkStreamId]
      guard let context = context else {
        logger.error("No context for Type2 header on stream \(chunkStreamId.value)")
        return nil
      }
      msgStreamId = context.messageStreamId
      messageType = context.messageType
      totalLength = context.messageLength

    } else if messageHeader is MessageHeaderType3 {
      // Get all fields from stream context
      let context = await chunkDecoder.streamContexts[chunkStreamId]
      guard let context = context else {
        logger.error("No context for Type3 header on stream \(chunkStreamId.value)")
        return nil
      }
      msgStreamId = context.messageStreamId
      messageType = context.messageType
      timestamp = context.timestamp
      totalLength = context.messageLength

    } else {
      logger.error("Unknown message header type")
      return nil
    }

    // Check if we're already assembling a message for this chunk stream
    if var assembling = assemblingMessages[chunkStreamId] {
      // Continue assembling existing message
      assembling.accumulatedData.append(chunk.chunkData)

      if assembling.accumulatedData.count >= assembling.totalLength {
        // Message complete - remove from assembling and return
        assemblingMessages.removeValue(forKey: chunkStreamId)
        return createMessage(
          chunkStreamId: chunkStreamId,
          msgStreamId: assembling.msgStreamId,
          messageType: assembling.messageType,
          timestamp: assembling.timestamp,
          chunkPayload: assembling.accumulatedData
        )
      } else {
        // Still need more chunks - update the assembling state
        assemblingMessages[chunkStreamId] = assembling
        return nil
      }
    } else {
      // Start new message or handle single-chunk message
      if chunk.chunkData.count >= totalLength {
        // Single-chunk message - complete immediately
        return createMessage(
          chunkStreamId: chunkStreamId,
          msgStreamId: msgStreamId,
          messageType: messageType,
          timestamp: timestamp,
          chunkPayload: chunk.chunkData
        )
      } else {
        // Multi-chunk message - start assembling
        assemblingMessages[chunkStreamId] = AssemblingMessage(
          msgStreamId: msgStreamId,
          messageType: messageType,
          timestamp: timestamp,
          totalLength: totalLength,
          accumulatedData: chunk.chunkData
        )
        return nil
      }
    }
  }

  // MARK: - Message Creation

  func createMessage(chunkStreamId: ChunkStreamId, msgStreamId: MessageStreamId, messageType: MessageType, timestamp: Timestamp, chunkPayload: Data) -> RTMPMessage? {
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
      return AbortMessage(chunkStreamId: chunkStreamId.value)
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
}
