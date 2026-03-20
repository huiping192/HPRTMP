import Foundation
import NIO

// NOT Sendable: AsyncStream.Continuation is not thread-safe; only used on a single NIO event loop.
final class RTMPClientHandler: ChannelInboundHandler {
  typealias InboundIn = ByteBuffer
  typealias BufferingPolicy = AsyncStream<Data>.Continuation.BufferingPolicy

  let stream: AsyncStream<Data>
  private var continuation: AsyncStream<Data>.Continuation?
  private let logger: RTMPLogger
  private var isFinished = false

  init(bufferingPolicy: BufferingPolicy = .unbounded, logger: RTMPLogger = RTMPLogger(category: "RTMPClientHandler")) {
    self.logger = logger
    let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: bufferingPolicy)
    self.stream = stream
    self.continuation = continuation
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    guard !isFinished, let continuation = continuation else { return }

    var buffer = self.unwrapInboundIn(data)

    var byteData = Data()
    buffer.readWithUnsafeReadableBytes { ptr in
      byteData.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
      return ptr.count
    }

    guard !byteData.isEmpty else { return }
    continuation.yield(byteData)
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    logger.error("[HPRTMP] Channel error: \(error)")
    finishStream()
    context.close(promise: nil)
  }

  func channelInactive(context: ChannelHandlerContext) {
    finishStream()
  }

  // prevent double-finish when both errorCaught and channelInactive fire
  private func finishStream() {
    guard !isFinished else { return }
    isFinished = true
    continuation?.finish()
    continuation = nil
  }
}
