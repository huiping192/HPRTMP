import Foundation
import NIO
import os

protocol NetworkConnectable {
  func connect(host: String, port: Int) async throws
  func sendData(_ data: Data) async throws
  func receiveData() async throws -> Data
  func close() async throws
}

final class RTMPClientHandler: ChannelInboundHandler {
  typealias InboundIn = ByteBuffer
  private let responseCallback: (Data) -> Void
  
  init(responseCallback: @escaping (Data) -> Void) {
    self.responseCallback = responseCallback
  }
  
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var buffer = self.unwrapInboundIn(data)
    
    var data = Data()
    buffer.readWithUnsafeReadableBytes { ptr in
      data.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
      return ptr.count
    }
    
    guard !data.isEmpty else { return }
    responseCallback(data)
  }
  
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("error: ", error)
    context.close(promise: nil)
  }
}

/**
 Data Reserver. If data is avaialable, use that data exactly once.
 If data is not available, wait data is comming with promise.
 When data is comming, client must call dataArrived.
 */
actor DataReserver {
  private var cachedData: Data = .init()
  private var dataPromise: EventLoopPromise<Data>?
  
  /**
   return cached data if it's not empty.
   Or return nil if it's empty.
   after calling this method, cachedData is renewed.
   */
  func tryRetrieveCache() -> Data? {
    if cachedData.isEmpty {
      return nil
    } else {
      let data = cachedData
      cachedData = Data()
      return data
    }
  }
  
  func waitData(with promise: EventLoopPromise<Data>) async throws -> Data {
    self.dataPromise = promise
    return try await promise.futureResult.get()
  }
  
  private func dataArrivedInner(data: Data) {
    cachedData.append(data)
    if let promise = dataPromise {
      self.dataPromise = nil
      let current = tryRetrieveCache()!
      promise.succeed(current)
    }
  }
  
  nonisolated func dataArrived(data: Data) {
    Task {
      await dataArrivedInner(data: data)
    }
  }
  
  func close() {
    dataPromise?.fail(NSError(domain: "RTMPClientError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Connection invalidated"]))
    dataPromise = nil
    cachedData = Data()
  }
}

class NetworkClient: NetworkConnectable {
  private let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  private var channel: Channel?
  private var host: String?
  private var port: Int?
  
  private let dataReserver = DataReserver()
  
  private let logger = Logger(subsystem: "HPRTMP", category: "NetworkClient")

  
  init() {
  }
  
  deinit {
    let group = group
    Task {
      try? await group.shutdownGracefully()
    }
  }
  
  func connect(host: String, port: Int) async throws {
    self.host = host
    self.port = port
        
    let bootstrap = ClientBootstrap(group: group)
      .channelInitializer { channel in
        channel.pipeline.addHandlers([
          RTMPClientHandler(responseCallback: self.responseReceived)
        ])
      }
    
    do {
      self.channel = try await bootstrap.connect(host: host, port: Int(port)).get()
      logger.info("[HPRTMP] Connected to \(host):\(port)")
    } catch {
      logger.error("[HPRTMP]  Failed to connect: \(error)")
      throw error
    }
  }
  
  func sendData(_ data: Data) async throws {
    guard let channel = self.channel else {
      throw NSError(domain: "RTMPClientError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection not established"])
    }
    
    let buffer = channel.allocator.buffer(bytes: data)
    try await channel.writeAndFlush(buffer)
  }
  
  func receiveData() async throws -> Data {
    guard let channel = self.channel else {
      throw NSError(domain: "RTMPClientError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection not established"])
    }
    if let cache = await dataReserver.tryRetrieveCache() {
      return cache
    }
    
    let waitPromise = channel.eventLoop.makePromise(of: Data.self)
    return try await dataReserver.waitData(with:waitPromise)
  }
  
  private func responseReceived(data: Data) {
    dataReserver.dataArrived(data: data)
  }
  
  func close() async throws {
    await dataReserver.close()
    let channel = self.channel
    self.channel = nil
    try await channel?.close()
  }
}
