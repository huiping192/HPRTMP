import Foundation

public struct PublishConfigure {
  let width: Int
  let height: Int
  let displayWidth: Int
  let displayHeight: Int
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  let videoframerate: Int
  
  public init(width: Int, height: Int, displayWidth: Int, displayHeight: Int, videocodecid: Int, audiocodecid: Int, framerate: Int, videoframerate: Int) {
    self.width = width
    self.height = height
    self.displayWidth = displayWidth
    self.displayHeight = displayHeight
    self.videocodecid = videocodecid
    self.audiocodecid = audiocodecid
    self.framerate = framerate
    self.videoframerate = videoframerate
  }
  
  var meta: [String: Any] {
    return [
      "width": Int32(width),
      "height": Int32(height),
      "displayWidth": Int32(displayWidth),
      "displayHeight": Int32(displayHeight),
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate,
      "videoframerate": videoframerate
    ]
  }
}


public protocol RTMPPublishSessionDelegate: AnyObject {
  func sessionStatusChange(_ session: RTMPPublishSession,  status: RTMPPublishSession.Status)
}

public class RTMPPublishSession {
  public enum Status: Equatable {
    case unknown
    case handShakeStart
    case handShakeDone
    case connect
    case publishStart
    case failed(err: RTMPError)
    case disconnected
    
    public static func ==(lhs: Status, rhs: Status) -> Bool {
      switch (lhs, rhs) {
      case (.unknown, .unknown),
        (.connect, .connect),
        (.publishStart, .publishStart),
        (.disconnected, .disconnected):
        return true
      case let (.failed(err1), .failed(err2)):
        return err1.localizedDescription == err2.localizedDescription
      default:
        return false
      }
    }
  }
  
  public weak var delegate: RTMPPublishSessionDelegate?
  
  public var publishStatus: Status = .unknown {
    didSet {
      delegate?.sessionStatusChange(self, status: publishStatus)
    }
  }
  
  public let encodeType: ObjectEncodingType = .amf0
  
  private let socket = RTMPSocket()
  
  private let transactionIdGenerator = TransactionIdGenerator()
  
  private var configure: PublishConfigure?
  
  private var connectId: Int = 0
  
  public init() {}
  
  public func publish(url: String, configure: PublishConfigure) {
    self.configure = configure
    socket.delegate = self
    socket.connect(url: url)
    
    publishStatus = .handShakeStart
  }
  
  private var videoHeaderSended = false
  private var audioHeaderSended = false

  public func publishVideoHeader(data: Data, time: UInt32) async throws {
    let message = VideoMessage(msgStreamId: connectId, data: data, timestamp: time)
    socket.send(message: message, firstType: true)
    videoHeaderSended = true
  }
  
  public func publishVideo(data: Data, delta: UInt32) async throws {
    guard videoHeaderSended else { return }
    let message = VideoMessage(msgStreamId: connectId, data: data, timestamp: delta)
    socket.send(message: message, firstType: false)
  }
  
  public func publishAudioHeader(data: Data) async throws {
    let message = AudioMessage(msgStreamId: connectId, data: data, timestamp: 0)
    socket.send(message: message, firstType: true)
    audioHeaderSended = true
  }
  
  public func publishAudio(data: Data, delta: UInt32) async throws {
    guard audioHeaderSended else { return }
    let message = AudioMessage(msgStreamId: connectId, data: data, timestamp: delta)
    socket.send(message: message, firstType: false)
  }
  
  public func invalidate() {
    self.socket.invalidate()
    self.publishStatus = .disconnected
  }
}

extension RTMPPublishSession: RTMPSocketDelegate {
  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse) {
    
  }
  
  func socketStreamOutputAudio(_ socket: RTMPSocket, data: Data, timeStamp: Int64, isFirst: Bool) {
    
  }
  
  func socketStreamOutputVideo(_ socket: RTMPSocket, data: Data, timeStamp: Int64, isFirst: Bool) {
    
  }
  
  func socketStreamPublishStart(_ socket: RTMPSocket) {
    print("[HPRTMP] socketStreamPublishStart")
    publishStatus = .publishStart
    guard let configure = configure else { return }
    let metaMessage = MetaMessage(encodeType: encodeType, msgStreamId: connectId, meta: configure.meta)
    socket.send(message: metaMessage, firstType: true)
  }
  
  func socketStreamRecord(_ socket: RTMPSocket) {
    
  }
  
  func socketStreamPlayStart(_ socket: RTMPSocket) {
    
  }
  
  func socketStreamPause(_ socket: RTMPSocket, pause: Bool) {
    
  }
  
  func socketConnectDone(_ socket: RTMPSocket) {
    publishStatus = .connect
    Task {
      let message = CreateStreamMessage(encodeType: encodeType, transactionId: await transactionIdGenerator.nextId())
      await self.socket.messageHolder.register(transactionId: message.transactionId, message: message)
      socket.send(message: message, firstType: true)
      
      // make chunk size more bigger
      let chunkSize: UInt32 = 1024*10
      let size = ChunkSizeMessage(size: chunkSize)
      socket.send(message: size, firstType: true)
    }
  }
  
  func socketHandShakeDone(_ socket: RTMPSocket) {
    publishStatus = .handShakeDone
    
    Task {
      guard let urlInfo = socket.urlInfo else { return }
      let connect = ConnectMessage(encodeType: encodeType,
                                   tcUrl: urlInfo.tcUrl,
                                   appName: urlInfo.appName,
                                   flashVer: "FMLE/3.0 (compatible; FMSc/1.0)",
                                   fpad: false,
                                   audio: .aac,
                                   video: .h264)
      await self.socket.messageHolder.register(transactionId: connect.transactionId, message: connect)
      self.socket.send(message: connect, firstType: true)
    }
  }
  
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int) {
    let message = PublishMessage(encodeType: encodeType, streamName: socket.urlInfo?.key ?? "", type: .live)
    
    message.msgStreamId = msgStreamId
    self.connectId = msgStreamId
    socket.send(message: message, firstType: true)
    publishStatus = .connect
  }
  
  func socketPinRequest(_ socket: RTMPSocket, data: Data) {
    let message = UserControlMessage(type: .pingResponse, data: data, streamId: connectId)
    socket.send(message: message, firstType: true)
  }
  
  func socketError(_ socket: RTMPSocket, err: RTMPError) {
    // todo : error handling
  }
  
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32) {
    // send window ack message  to server
    socket.send(message: WindowAckMessage(size: size), firstType: true)
  }
  
  func socketDisconnected(_ socket: RTMPSocket) {
    publishStatus = .disconnected
  }
  
  
}

