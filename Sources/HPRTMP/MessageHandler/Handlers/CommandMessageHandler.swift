//
//  CommandMessageHandler.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/06.
//

import Foundation
import os

/// Handles RTMP command messages (onStatus, onMetaData, _result, _error)
struct CommandMessageHandler: RTMPMessageHandler {
  private let logger = Logger(subsystem: "HPRTMP", category: "CommandMessageHandler")
  func canHandle(_ message: RTMPMessage) -> Bool {
    return message is CommandMessage
  }

  func handle(_ message: RTMPMessage, context: MessageHandlerContext) async {
    guard let commandMessage = message as? CommandMessage else { return }

    logger.info("CommandMessage, \(commandMessage.description)")

    // Handle onStatus messages
    if commandMessage.commandNameType == .onStatus {
      await handleOnStatus(commandMessage, context: context)
      return
    }

    // Handle onMetaData messages
    if commandMessage.commandNameType == .onMetaData {
      await handleOnMetaData(commandMessage, context: context)
      return
    }

    // Handle responses to sent commands (connect, createStream, etc.)
    await handleCommandResponse(commandMessage, context: context)
  }

  private func handleOnStatus(_ commandMessage: CommandMessage, context: MessageHandlerContext) async {
    guard let statusResponse = StatusResponse(info: commandMessage.info) else { return }

    if statusResponse.level == .error {
      logger.error("Status error: \(statusResponse.description ?? "")")
      return
    }

    guard let code = statusResponse.code else { return }

    switch code {
    case .publishStart:
      await context.eventDispatcher.yieldStream(.publishStart)
    case .playStart:
      await context.eventDispatcher.yieldStream(.playStart)
    case .pauseNotify:
      await context.eventDispatcher.yieldStream(.pause(true))
    case .unpauseNotify:
      await context.eventDispatcher.yieldStream(.pause(false))
    default:
      break
    }
  }

  private func handleOnMetaData(_ commandMessage: CommandMessage, context: MessageHandlerContext) async {
    guard let meta = MetaDataResponse(commandObject: commandMessage.commandObject) else { return }
    await context.eventDispatcher.yieldMedia(.metadata(meta))
  }

  private func handleCommandResponse(_ commandMessage: CommandMessage, context: MessageHandlerContext) async {
    let message = await context.messageHolder.removeMessage(transactionId: commandMessage.transactionId)

    switch message {
    case is ConnectMessage:
      await handleConnectResponse(commandMessage, context: context)

    case is CreateStreamMessage:
      await handleCreateStreamResponse(commandMessage, context: context)

    default:
      break
    }
  }

  private func handleConnectResponse(_ commandMessage: CommandMessage, context: MessageHandlerContext) async {
    if commandMessage.commandNameType == .result {
      let connectResponse = ConnectResponse(info: commandMessage.info)
      if connectResponse?.code == .success {
        logger.info("Connect Success")
        context.resumeConnect(.success(()))
      } else {
        logger.error("Connect failed")
        let error = RTMPError.command(desc: connectResponse?.code.rawValue ?? "Connect error")
        context.resumeConnect(.failure(error))
      }
    }
  }

  private func handleCreateStreamResponse(_ commandMessage: CommandMessage, context: MessageHandlerContext) async {
    if commandMessage.commandNameType == .result {
      logger.info("Create Stream Success")
      context.updateStatus(.connected)

      let streamId = Int(commandMessage.info?.doubleValue ?? 0)
      context.resumeCreateStream(commandMessage.transactionId, .success(MessageStreamId(streamId)))
    } else {
      logger.error("Create Stream failed, \(commandMessage.info.debugDescription)")
      let error = RTMPError.command(desc: "Create Stream error")
      context.resumeCreateStream(commandMessage.transactionId, .failure(error))
    }
  }
}
