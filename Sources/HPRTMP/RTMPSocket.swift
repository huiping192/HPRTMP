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
  case stream(desc: String)
  case command(desc: String)
  case uknown(desc: String)
  var localizedDescription: String {
    get {
      switch self {
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
  func socketCreateStreamDone(_ socket: RTMPSocket)
  func socketError(_ socket: RTMPSocket, err: RTMPError)
  //  func socketGetMeta(_ socket: RTMPSocket, meta: MetaDataResponse)
  func socketPeerBandWidth(_ socket: RTMPSocket, size: UInt32)
  func socketDisconnected(_ socket: RTMPSocket)
}

actor MessageHolder {
  private (set) var transactionId = 1
  
  var raw = [Int: RTMPBaseMessage]()
  
  func register(message: RTMPBaseMessage) {
    raw[transactionId] = message
  }
  
  func removeMessage(id: Int) -> RTMPBaseMessage? {
    let value = raw[transactionId]
    raw[transactionId] = nil
    return value
  }
  
  @discardableResult
  func shiftTransactionId () -> Int {
    self.transactionId += 1
    return self.transactionId
  }
}

public class RTMPSocket {
  
  private var connection: NWConnection?
  
  private var status: RTMPStatus = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  private(set) var urlInfo: RTMPURLInfo?
  
  let messageHolder = MessageHolder()
  
  var connectId: Int = 0
  
  private let encoder = ChunkEncoder()
  private let decoder = MessageDecoder()
  
  private var handshake: RTMPHandshake?
  
  public init() {}
  
  
  public func connect(url: String) {
    let urlParser = RTMPURLParser()
    guard let urlInfo = try? urlParser.parse(url: url) else { return }
    self.urlInfo = urlInfo
    
    resume()
  }
  
  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) {
    let urlInfo = RTMPURLInfo(url: streamURL, key: streamKey, port: port)
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
    connection.stateUpdateHandler = { newState in
      print("[HPRTMP] connection \(connection) state: \(newState)")
      switch newState {
      case .ready:
        Task {
          try await self.handshake?.start()
          self.delegate?.socketHandShakeDone(self)
          // handshake終わったあとのデータ取得
          try await self.startReceiveData()
        }
      case .failed(let error):
        print("[HPRTMP] connection error: \(error.localizedDescription)")
        self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
        self.invalidate()
      default:
        break
      }
    }
    
    handshake = RTMPHandshake(dataSender: connection.sendData, dataReceiver: connection.receiveData)
    connection.start(queue: DispatchQueue.global(qos: .default))
  }
  
  
  public func invalidate() {
    guard status != .closed && status != .none else { return }
    Task {
      await handshake?.reset()
      await decoder.reset()
      encoder.reset()
      //    info.reset(clearInfo)
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


extension Stream.Event: CustomStringConvertible {
  public var description: String {
    switch self {
    case Stream.Event.openCompleted:
      return "openCompleted"
    case Stream.Event.hasBytesAvailable:
      return "hasBytesAvailable"
    case Stream.Event.hasSpaceAvailable:
      return "hasSpaceAvailable"
    case Stream.Event.errorOccurred:
      return "errorOccurred"
    case Stream.Event.endEncountered:
      return "endEncountered"
    default:
      return "unknown"
    }
  }
}

extension RTMPSocket {
  func send(message: RTMPMessage & Encodable, firstType: Bool = false) async throws {
    print("[HPRTMP] send message start: \(message)")
    
    if let message = message as? ChunkSizeMessage {
      encoder.chunkSize = message.size
    }
    let datas = encoder.chunk(message: message, isFirstType0: firstType).map({ $0.encode() })
    do {
      try await self.sendChunk(datas)
      print("[HPRTMP] send message successd: \(message)")
    } catch {
      print("[HPRTMP] send message failed: \(message), error: \(error)")
      throw error
    }
    
  }
  
  private func sendChunk(_ data: [Data]) async throws {
    try await connection?.sendData(data)
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) {
    let length = data.count
    guard length > 0 else { return }
    
    Task {
      await decoder.append(data)
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
    
    if let windowAckMessage  = message as? WindowAckMessage {
      print("[HTRTMP] WindowAckMessage, size \(windowAckMessage.size)")
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
    
    if let createStreamMessage = message as? CreateStreamMessage {
      print("[HTRTMP] CreateStreamMessage, \(createStreamMessage.description)")
      self.delegate?.socketCreateStreamDone(self)
      return
    }
    
    if let commandMessage = message as? CommandMessage {
      print("[HTRTMP] CommandMessage, \(commandMessage.description)")

      let message = await messageHolder.removeMessage(id: commandMessage.transactionId)
      switch message {
      case is ConnectMessage:
        let commandName = commandMessage.commandName
        if commandName == "_result" {
          let info = commandMessage.info
          if info?["code"] as? String == "NetConnection.Connect.Success" {
            print("[HTRTMP] Connect Success")
            self.delegate?.socketConnectDone(self)
          } else {
            print("[HTRTMP] Connect failed")
            // connect failed
          }
        }
      case is CreateStreamMessage:
        let commandName = commandMessage.commandName
        if commandName == "_result" {
          print("[HTRTMP] Create Stream Success")
          self.status = .connected
          self.delegate?.socketCreateStreamDone(self)
        } else {
          print("[HTRTMP] Create Stream failed")
        }
      default:
        break
      }

      return
    }
        
    if let controlMessage = message as? ControlMessage {
      print("[HTRTMP] ControlMessage, message Type:  \(controlMessage.messageType)")
      
      return
    }
  }
}
