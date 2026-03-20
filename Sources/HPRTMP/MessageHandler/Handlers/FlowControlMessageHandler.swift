//
//  FlowControlMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation

struct FlowControlMessageHandler: RTMPMessageHandler {
  private let logger: RTMPLogger

  init(logger: RTMPLogger = RTMPLogger(category: "FlowControlMessageHandler")) {
    self.logger = logger
  }
  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is WindowAckMessage
      || message is AcknowledgementMessage
      || message is PeerBandwidthMessage
      || message is ChunkSizeMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    switch message {
    case let windowAckMessage as WindowAckMessage:
      await handleWindowAck(windowAckMessage, context: context)

    case let acknowledgementMessage as AcknowledgementMessage:
      await handleAcknowledgement(acknowledgementMessage, context: context)

    case let peerBandwidthMessage as PeerBandwidthMessage:
      await handlePeerBandwidth(peerBandwidthMessage, context: context)

    case let chunkSizeMessage as ChunkSizeMessage:
      await handleChunkSize(chunkSizeMessage, context: context)

    default:
      break
    }
  }

  private func handleWindowAck(_ message: WindowAckMessage, context: MessageHandlerContext) async {
    logger.info("WindowAckMessage, size \(message.size)")
    await context.windowControl.setWindowSize(message.size)
  }

  private func handleAcknowledgement(_ message: AcknowledgementMessage, context: MessageHandlerContext) async {
    logger.info("AcknowledgementMessage, size \(message.sequence)")
    await context.windowControl.updateReceivedAcknowledgement(message.sequence)
  }

  private func handlePeerBandwidth(_ message: PeerBandwidthMessage, context: MessageHandlerContext) async {
    logger.info("PeerBandwidthMessage, size \(message.windowSize)")
    await context.tokenBucket.update(
      rate: Int(message.windowSize),
      capacity: Int(message.windowSize)
    )
    await context.eventDispatcher.yieldConnection(.peerBandwidthChanged(message.windowSize))
  }

  private func handleChunkSize(_ message: ChunkSizeMessage, context: MessageHandlerContext) async {
    logger.info("chunkSizeMessage, size \(message.size)")
    await context.decoder.setMaxChunkSize(maxChunkSize: Int(message.size))
  }
}
