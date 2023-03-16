//
//  RTMPSocket.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import AVFoundation
import Network


public enum RTMPState {
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
  //  func socketConnectDone(_ socket: RTMPSocket, obj: ConnectResponse)
  //  func socketCreateStreamDone(_ socket: RTMPSocket, obj: StreamResponse)
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
  
  private var inputData = Data()
  
  private var state: RTMPState = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  private(set) var urlInfo: RTMPURLInfo?
  
  let messageHolder = MessageHolder()
  
  var connectId: Int = 0
  
  private let encoder = ChunkEncoder()
  private let decoder = ChunkDecoder()

  private var handshake: RTMPHandshake?
  
  public init() {}
  
  
  public func connect(url: String) {
    let urlParser = RTMPURLParser()
    guard let urlInfo = try? urlParser.parse(url: url) else { return }
    self.urlInfo = urlInfo
  }
  
  public func connect(streamURL: URL, streamKey: String, port: Int = 1935) {
    let urlInfo = RTMPURLInfo(url: streamURL, key: streamKey, port: port)
    self.urlInfo = urlInfo
  }
}

// public func
extension RTMPSocket {
  public func resume() {
    guard state != .connected else { return }
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
    guard state != .closed && state != .none else { return }
    Task {
      await handshake?.reset()
    }
    decoder.reset()
    encoder.reset()
//    info.reset(clearInfo)
  }
  
  private func startReceiveData() async throws {
    guard let connection else { return }
    while true {
      let data = try await connection.receiveData()
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
  func send(message: RTMPBaseMessageProtocol & Encodable, firstType: Bool = false) async throws {
    if let message = message as? ChunkSizeMessage {
      encoder.chunkSize = message.size
    }
    try await self.sendChunk(encoder.chunk(message: message, isFirstType0: firstType))
  }
  
  private func sendChunk(_ data: [Data]) async throws {
    try await connection?.sendData(data)
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) {
    let length = data.count
    guard length > 0 else { return }
    inputData.append(data)
    let bytes: Data = self.inputData
    self.inputData.removeAll()
    self.decode(data: bytes)
  }
  
  private func decode(data: Data) {
      self.decoder.decode(data: data) { [unowned self] (header) in
//          switch header.messageHeader {
//          case let c as MessageHeaderType0:
//              self.chunk(header0: c, chunk: header)
//          case let c as MessageHeaderType1:
//              self.chunk(header1: c, chunk: header)
//          default:
//              break
//          }
      }
  }
  
}
