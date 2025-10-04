import Foundation
import NIO
import os

final class RTMPClientHandler: ChannelInboundHandler, Sendable {
  typealias InboundIn = ByteBuffer
  private let continuation: AsyncStream<Data>.Continuation
  let stream: AsyncStream<Data>
  private let logger = Logger(subsystem: "HPRTMP", category: "RTMPClientHandler")

  init() {
    (stream, continuation) = AsyncStream<Data>.makeStream()
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var buffer = self.unwrapInboundIn(data)

    var data = Data()
    buffer.readWithUnsafeReadableBytes { ptr in
      data.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
      return ptr.count
    }

    guard !data.isEmpty else { return }
    continuation.yield(data)
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    logger.error("[HPRTMP] Channel error: \(error)")
    continuation.finish()
    context.close(promise: nil)
  }

  func channelInactive(context: ChannelHandlerContext) {
    continuation.finish()
  }
}
