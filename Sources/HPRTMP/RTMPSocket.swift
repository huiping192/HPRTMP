//
//  RTMPSocket.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import Network


public enum RTMPStatus {
  case none
  case open
  case connected
  case closed
}

public enum RTMPError: Error {
  case handShake(desc: String)
  case stream(desc: String)
  case command(desc: String)
  case uknown(desc: String)
  var localizedDescription: String {
    get {
      switch self {
      case .handShake(let desc):
        return desc
      case .stream(let desc):
        return desc
      case .command(let desc):
        return desc
      case .uknown(let desc):
        return desc
      }
    }
  }
}

protocol RTMPSocketDelegate: AnyObject {
  func socketHandShakeDone(_ socket: RTMPSocket)
  func socketPinRequest(_ socket: RTMPSocket, data: Data)
  func socketConnectDone(_ socket: RTMPSocket)
  func socketCreateStreamDone(_ socket: RTMPSocket, msgStreamId: Int)
  func socketError(_ socket: RTMPSocket, err: RTMPError)
  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse)
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32)
  func socketDisconnected(_ socket: RTMPSocket)
  
  
  func socketStreamOutputAudio(_ socket: RTMPSocket, data: Data, timeStamp: Int64)
  func socketStreamOutputVideo(_ socket: RTMPSocket, data: Data, timeStamp: Int64)
  func socketStreamPublishStart(_ socket: RTMPSocket)
  func socketStreamRecord(_ socket: RTMPSocket)
  func socketStreamPlayStart(_ socket: RTMPSocket)
  func socketStreamPause(_ socket: RTMPSocket, pause: Bool)
}

public class RTMPSocket {
  
  private var connection: NWConnection?
  
  private var status: RTMPStatus = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  private(set) var urlInfo: RTMPURLInfo?
  
  let messageHolder = MessageHolder()
  
  private let encoder = ChunkEncoder()
  private let decoder = MessageDecoder()
  
  private var handshake: RTMPHandshake?
  
  private let windowControl = WindowControl()
  
  public init() {
    Task {
      await windowControl.setInBytesWindowEvent { [weak self]inbytesCount in
        self?.sendAcknowledgementMessage(sequence: inbytesCount)
      }
    }
  }
  
  private func sendAcknowledgementMessage(sequence: UInt32) {
    Task {
      guard status == .connected else { return }
      try await self.send(message: AcknowledgementMessage(sequence: UInt32(sequence)), firstType: true)
    }
  }
  
  
  public func connect(url: String) {

    let urlParser = RTMPURLParser()
    guard let urlInfo = try? urlParser.parse(url: url) else { return }
    self.urlInfo = urlInfo
    
    resume()
  }
  
  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) {
    let urlInfo = RTMPURLInfo(url: streamURL, appName: "", key: streamKey, port: port)
    self.urlInfo = urlInfo
  }
}

// public func
extension RTMPSocket {
  public func resume() {
    guard status != .connected else { return }
    guard let urlInfo else { return }
    let port = NWEndpoint.Port(rawValue: UInt16(urlInfo.port))
    let host = NWEndpoint.Host(urlInfo.host)
    let connection = NWConnection(host: host, port: port ?? 1935, using: .tcp)
    self.connection = connection
    connection.stateUpdateHandler = { [weak self]newState in
      guard let self else { return }
      print("[HPRTMP] connection \(connection) state: \(newState)")
      switch newState {
      case .ready:
        guard status == .open else { return }
        startShakeHands()
      case .failed(let error):
        print("[HPRTMP] connection error: \(error.localizedDescription)")
        self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
        self.invalidate()
      default:
        break
      }
    }
    
    status = .open
    connection.start(queue: DispatchQueue.global(qos: .default))
  }
  
  private func startShakeHands() {
    Task {
      guard let connection = self.connection else { return }
      self.handshake = RTMPHandshake(dataSender: connection.sendData, dataReceiver: connection.receiveData)
      await self.handshake?.setDelegate(delegate: self)
      do {
        try await self.handshake?.start()
      } catch {
        self.delegate?.socketError(self, err: .handShake(desc: error.localizedDescription))
      }
    }
  }
  
  public func invalidate() {
    guard status != .closed && status != .none else { return }
    Task {
      await handshake?.reset()
      await decoder.reset()
      encoder.reset()
      connection?.cancel()
      connection = nil
      urlInfo = nil
      status = .closed
      delegate?.socketDisconnected(self)
    }
  }
  
  private func startReceiveData() async throws {
    guard let connection else { return }
    while true {
      let data = try await connection.receiveData()
      print("[HPRTMP] receive data count: \(data.count)")
      self.handleOutputData(data: data)
    }
  }
}

extension RTMPSocket {
  func send(message: RTMPMessage & Encodable, firstType: Bool) async throws {
    print("[HPRTMP] send message start: \(message)")
    
    if let message = message as? ChunkSizeMessage {
      encoder.chunkSize = message.size
    }
    let datas = encoder.chunk(message: message, isFirstType0: firstType).map({ $0.encode() })
    do {
      try await connection?.sendData(datas)
      await windowControl.addOutBytesCount(UInt32(datas.count))
      print("[HPRTMP] send message successd: \(message)")
    } catch {
      print("[HPRTMP] send message failed: \(message), error: \(error)")
      delegate?.socketError(self, err: .stream(desc: error.localizedDescription))
    }
  }
}

extension RTMPSocket: RTMPHandshakeDelegate {
  func rtmpHandshakeDidChange(status: RTMPHandshake.Status) {
    guard status == .handshakeDone else { return }
    Task {
      do {
        self.delegate?.socketHandShakeDone(self)
        // handshake終わったあとのデータ取得
        try await startReceiveData()
      } catch {
        self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
      }
    }
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) {
    guard !data.isEmpty else { return }
    Task {
      await windowControl.addInBytesCount(UInt32(data.count))
      await decoder.append(data)
      
      if await decoder.isDecoding {
        return
      }
      var dataRemainCount = 0
      while await decoder.remainDataCount != dataRemainCount, await decoder.remainDataCount != 0 {
        dataRemainCount = await decoder.remainDataCount
        await decode(data: data)
      }
    }
    
  }
  
  private func decode(data: Data) async {
    guard let message = await decoder.decode() else {
      print("[HPRTMP] decode message need more data.")
      return
    }
    
    if let windowAckMessage = message as? WindowAckMessage {
      print("[HTRTMP] WindowAckMessage, size \(windowAckMessage.size)")
      await windowControl.setWindowSize(windowAckMessage.size)
      return
    }
    
    if let acknowledgementMessage = message as? AcknowledgementMessage {
      print("[HTRTMP] AcknowledgementMessage, size \(acknowledgementMessage.sequence)")
      return
    }
    
    if let peerBandwidthMessage = message as? PeerBandwidthMessage {
      print("[HTRTMP] PeerBandwidthMessage, size \(peerBandwidthMessage.windowSize)")
      delegate?.socketPeerBandWidth(self, size: peerBandwidthMessage.windowSize)
      return
    }
    
    if let chunkSizeMessage = message as? ChunkSizeMessage {
      print("[HTRTMP] chunkSizeMessage, size \(chunkSizeMessage.size)")
      await decoder.setMaxChunkSize(maxChunkSize: Int(chunkSizeMessage.size))
      return
    }
    
    if let commandMessage = message as? CommandMessage {
      print("[HTRTMP] CommandMessage, \(commandMessage.description)")
      await handleCommandMessage(commandMessage)
      return
    }
    
    if let userControlMessage = message as? UserControlMessage {
      print("[HTRTMP] UserControlMessage, message Type:  \(userControlMessage.type)")
      switch userControlMessage.type {
      case .pingRequest:
        self.delegate?.socketPinRequest(self, data: userControlMessage.data)
      case .streamIsRecorded:
        self.delegate?.socketStreamRecord(self)
      default:
        break
      }
    }
    
    if let controlMessage = message as? ControlMessage {
      print("[HTRTMP] ControlMessage, message Type:  \(controlMessage.messageType)")
      
      return
    }
    
    if let dataMessage = message as? DataMessage {
      print("[HTRTMP] DataMessage, message Type:  \(dataMessage.messageType)")
      
      return
    }
    
    if let videoMessage = message as? VideoMessage {
      print("[HTRTMP] VideoMessage, message Type:  \(videoMessage.messageType)")
      self.delegate?.socketStreamOutputVideo(self, data: videoMessage.data, timeStamp: Int64(videoMessage.timestamp))
      return
    }
    
    if let audioMessage = message as? AudioMessage {
      print("[HTRTMP] AudioMessage, message Type:  \(audioMessage.messageType)")
      self.delegate?.socketStreamOutputAudio(self, data: audioMessage.data, timeStamp: Int64(audioMessage.timestamp))
      return
    }
    
    if let sharedObjectMessage = message as? SharedObjectMessage {
      print("[HTRTMP] ShareMessage, message Type:  \(sharedObjectMessage.messageType)")
      return
    }
    
    if let abortMessage = message as? AbortMessage {
      print("[HTRTMP] AbortMessage, message Type:  \(abortMessage.chunkStreamId)")
      return
    }
  }
  
  private func handleCommandMessage(_ commandMessage: CommandMessage) async {
    if commandMessage.commandNameType == .onStatus {
      guard let statusResponse = StatusResponse(info: commandMessage.info) else { return }
      if statusResponse.level == .error {
        self.delegate?.socketError(self, err: .command(desc: statusResponse.description ?? ""))
        return
      }
      switch statusResponse.code {
      case .publishStart:
        self.delegate?.socketStreamPublishStart(self)
      case .playStart:
        self.delegate?.socketStreamPlayStart(self)
      case .pauseNotify:
        self.delegate?.socketStreamPause(self, pause: true)
      case .unpauseNotify:
        self.delegate?.socketStreamPause(self, pause: false)
      default:
        break
      }
      return
    }
    
    // meta data
    if commandMessage.commandNameType == .onMetaData {
      guard let meta = MetaDataResponse(commandObject: commandMessage.commandObject) else { return }
      self.delegate?.socketGetMeta(self, meta: meta)
      return
    }
    
    // back from server
    let message = await messageHolder.removeMessage(transactionId: commandMessage.transactionId)
    switch message {
    case is ConnectMessage:
      if commandMessage.commandNameType == .result {
        let connectResponse = ConnectResponse(info: commandMessage.info)
        if connectResponse?.code == .success {
          print("[HTRTMP] Connect Success")
          self.delegate?.socketConnectDone(self)
        } else {
          print("[HTRTMP] Connect failed")
          self.delegate?.socketError(self, err: .command(desc: connectResponse?.code.rawValue ?? "Connect error"))
        }
      }
    case is CreateStreamMessage:
      if commandMessage.commandNameType == .result {
        print("[HTRTMP] Create Stream Success")
        self.status = .connected
        
        let msgStreamId = commandMessage.info as? Double ?? 0
        self.delegate?.socketCreateStreamDone(self, msgStreamId: Int(msgStreamId))
      } else {
        print("[HTRTMP] Create Stream failed, \(commandMessage.info ?? "")")
        self.delegate?.socketError(self, err: .command(desc: "Create Stream error"))
      }
    default:
      break
    }
  }
}
