import Foundation
import NIO
import os

actor NetworkClient: NetworkConnectable {
  private let group: EventLoopGroup
  private var channel: Channel?
  private var host: String?
  private var port: Int?
  private var isGroupShutdown = false
  private var streamConsumerTask: Task<Void, Never>?

  private let dataReservoir = DataReservoir()

  private let logger = Logger(subsystem: "HPRTMP", category: "NetworkClient")


  init(numberOfThreads: Int = 1) {
    self.group = MultiThreadedEventLoopGroup(numberOfThreads: numberOfThreads)
  }
  
  func connect(host: String, port: Int) async throws {
    self.host = host
    self.port = port

    let handler = RTMPClientHandler()
    let bootstrap = ClientBootstrap(group: group)
      .channelInitializer { channel in
        channel.pipeline.addHandlers([handler])
      }

    do {
      self.channel = try await bootstrap.connect(host: host, port: Int(port)).get()
      logger.info("[HPRTMP] Connected to \(host):\(port)")

      streamConsumerTask = Task { [weak self] in
        for await data in handler.stream {
          if Task.isCancelled { return }
          await self?.dataReservoir.dataArrived(data: data)
        }
      }
    } catch {
      logger.error("[HPRTMP]  Failed to connect: \(error)")
      throw error
    }
  }
  
  func sendData(_ data: Data) async throws {
    guard let channel = self.channel else {
      throw RTMPError.connectionNotEstablished
    }

    let buffer = channel.allocator.buffer(bytes: data)
    try await channel.writeAndFlush(buffer)
  }

  func receiveData() async throws -> Data {
    guard let channel = self.channel else {
      throw RTMPError.connectionNotEstablished
    }
    if let cache = await dataReservoir.tryRetrieveCache() {
      return cache
    }

    let waitPromise = channel.eventLoop.makePromise(of: Data.self)
    return try await dataReservoir.waitData(with:waitPromise)
  }

  func close() async throws {
    // Cancel stream consumer first to stop processing new data
    streamConsumerTask?.cancel()
    streamConsumerTask = nil

    // Close channel before cleaning up other resources
    let channel = self.channel
    self.channel = nil
    try await channel?.close()

    // Close data reservoir after channel is closed
    await dataReservoir.close()

    // Shutdown group only if not already done, and set flag AFTER success
    if !isGroupShutdown {
      try await group.shutdownGracefully()
      isGroupShutdown = true
    }
  }
}
