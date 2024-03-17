import Foundation
import NIO

final class RTMPClientHandler: ChannelInboundHandler {
  typealias InboundIn = Data
  private let responseCallback: (Data) -> Void
  
  init(responseCallback: @escaping (Data) -> Void) {
    self.responseCallback = responseCallback
  }
  
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let data = self.unwrapInboundIn(data)
    responseCallback(data)
  }
}

final class DataDecoder: ByteToMessageDecoder {
  typealias InboundIn = ByteBuffer
  typealias InboundOut = Data
  
  func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
    var data = Data()
    buffer.readWithUnsafeReadableBytes { ptr in
      data.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
      return ptr.count
    }
    context.fireChannelRead(wrapInboundOut(data))
    return .continue
  }
}

final class DataEncoder: MessageToByteEncoder {
  typealias OutboundIn = Data
  typealias OutboundOut = ByteBuffer
  
  func encode(data: Data, out: inout ByteBuffer) throws {
    out.writeBytes(data)
  }
}

class RTMPClient: RTMPConnectable {
  private let group: EventLoopGroup
  private var channel: Channel?
  private let host: String
  private let port: Int
  
  private var dataPromise: EventLoopPromise<Data>?
  
  init(host: String, port: Int) {
    self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.host = host
    self.port = port
  }
  
  func connect(host: String, port: UInt16) async throws {
    let bootstrap = ClientBootstrap(group: group)
      .channelInitializer { channel in
        channel.pipeline.addHandlers([
          ByteToMessageHandler(DataDecoder()),
          MessageToByteHandler(DataEncoder()),
          RTMPClientHandler(responseCallback: self.responseReceived)
        ])
      }
    
    do {
      self.channel = try await bootstrap.connect(host: host, port: Int(port)).get()
      print("Connected to \(host):\(port)")
    } catch {
      print("Failed to connect: \(error)")
      throw error
    }
  }
  
  func sendData(_ data: Data) async throws {
    guard let channel = self.channel else {
      print("Connection not established")
      throw NSError(domain: "RTMPClientError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection not established"])
    }
    
    try await channel.writeAndFlush(data)
  }
  
  func receiveData() async throws -> Data {
    guard let promise = self.dataPromise else {
      throw NSError(domain: "RTMPClientError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Data promise is not initialized."])
    }
    self.dataPromise = channel!.eventLoop.makePromise(of: Data.self)
    return try await promise.futureResult.get()
  }
  
  private func responseReceived(data: Data) {
    self.dataPromise?.succeed(data)
  }
  
  func shutdown() {
    do {
      try group.syncShutdownGracefully()
    } catch {
      print("Error shutting down: \(error)")
    }
  }
}
