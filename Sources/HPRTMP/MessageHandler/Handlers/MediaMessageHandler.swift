//
//  MediaMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles media messages (video and audio)
struct MediaMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "MediaMessageHandler")

  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is VideoMessage || message is AudioMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    switch message {
    case let videoMessage as VideoMessage:
      await handleVideo(videoMessage, context: context)

    case let audioMessage as AudioMessage:
      await handleAudio(audioMessage, context: context)

    default:
      break
    }
  }

  private func handleVideo(_ message: VideoMessage, context: MessageHandlerContext) async {
    logger.info("VideoMessage, message Type: \(message.messageType.rawValue)")
    await context.eventDispatcher.yieldMedia(
      .video(data: message.data, timestamp: Int64(message.timestamp.value))
    )
  }

  private func handleAudio(_ message: AudioMessage, context: MessageHandlerContext) async {
    logger.info("AudioMessage, message Type: \(message.messageType.rawValue)")
    await context.eventDispatcher.yieldMedia(
      .audio(data: message.data, timestamp: Int64(message.timestamp.value))
    )
  }
}
