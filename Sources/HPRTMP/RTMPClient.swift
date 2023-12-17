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

class RTMPClient {
    private let group: EventLoopGroup
    private var channel: Channel?
    private let host: String
    private let port: Int
    private var responseCallback: ((Data) -> Void)?

    init(host: String, port: Int) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.host = host
        self.port = port
    }

    func connect(responseCallback: @escaping (Data) -> Void) {
        self.responseCallback = responseCallback
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ByteToMessageHandler(DataDecoder()),
                    MessageToByteHandler(DataEncoder()),
                    RTMPClientHandler(responseCallback: self.responseReceived)
                ])
            }

        do {
            self.channel = try bootstrap.connect(host: host, port: port).wait()
            print("Connected to \(host):\(port)")
        } catch {
            print("Failed to connect: \(error)")
        }
    }

    func send(data: Data) {
        guard let channel = channel else {
            print("Connection not established")
            return
        }
        channel.writeAndFlush(data, promise: nil)
    }

    private func responseReceived(data: Data) {
        responseCallback?(data)
    }

    func shutdown() {
        do {
            try group.syncShutdownGracefully()
        } catch {
            print("Error shutting down: \(error)")
        }
    }
}
