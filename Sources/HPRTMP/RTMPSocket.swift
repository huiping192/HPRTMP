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


public class RTMPSocket: NSObject {
  
  private static let maxReadSize = Int(UInt16.max)
  
  private let inputQueue = DispatchQueue(label: "HPRTMP.inputQueue")
  private let outputQueue = DispatchQueue(label: "HPRTMP.outputQueue")
    
  private var connection: NWConnection?
  
  private var buffer: UnsafeMutablePointer<UInt8>?
  private var inputData = Data()
  
  private var state: RTMPState = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  let urlInfo: RTMPURLInfo
  
  var connectId: Int = 0
  
  private let encoder = ChunkEncoder()
  private let decoder = ChunkDecoder()

  
  private lazy var handshake: RTMPHandshake = {
    return RTMPHandshake(statusChange: { [weak self] (status) in
      guard let self = self else { return }
      print("[HPRTMP] handshake status: \(status)")
      switch status {
      case .uninitalized:
        self.send(self.handshake.c0c1Packet) {
          self.startReceiveData()
        }

        print("[HPRTMP] send handshake c0c1Packet")
      case .verSent:
        self.send(self.handshake.c2Packet)
        print("[HPRTMP] send handshake c2Packet")
      case .ackSent, .none:
        break
      case .handshakeDone:
        self.delegate?.socketHandShakeDone(self)
      }
    })
  }()
  
  public init?(url: String) {
    let urlParser = RTMPURLParser()
    guard let urlInfo = try? urlParser.parse(url: url) else { return nil }
    self.urlInfo = urlInfo
  }
  
  public init?(streamURL: URL, streamKey: String, port: Int = 1935) {
    let urlInfo = RTMPURLInfo(url: streamURL, key: streamKey, port: port)
    self.urlInfo = urlInfo
  }
  
  
  
}

// public func
extension RTMPSocket {
  public func resume() {
    guard state != .connected else { return }
    inputQueue.async { [unowned self] in
      let port = NWEndpoint.Port(rawValue: UInt16(urlInfo.port))
      let host = NWEndpoint.Host(urlInfo.host)
      let connection = NWConnection(host: host, port: port ?? 1935, using: .tcp)
      self.connection = connection
      connection.stateUpdateHandler = { newState in
        print("[HPRTMP] connection \(connection) state: \(newState)")
          switch newState {
          case .ready:
            self.handshake.startHandShake()
          case .failed(let error):
            print("[HPRTMP] connection error: \(error.localizedDescription)")
            self.delegate?.socketError(self, err: .uknown(desc: error.localizedDescription))
            self.invalidate()
          default:
              break
          }
      }
      connection.start(queue: self.outputQueue)
    }
  }
  
  private func startReceiveData() {
    connection?.receive(minimumIncompleteLength: 1, maximumLength: 1536) { [weak self](data, context, isComplete, error) in
      guard let self else { return }
      
      self.outputQueue.async {
        print("[HPRTMP] test \(data), \(context), \(isComplete), \(error)")
        guard let data else { return }
        self.handleOutputData(data: data)
        
        if isComplete {
          self.connection?.cancel()
        } else {
          self.startReceiveData()
        }
      }
    }
  }
  
  public func invalidate() {
    guard state != .closed && state != .none else { return }
//    self.clearParameter()
    handshake.reset()
    //        decoder.reset()
    //        encoder.reset()
    //        info.reset(clearInfo)
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


//extension RTMPSocket: StreamDelegate {
//  public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//    print("[HPRTMP] stream \(aStream) eventCode: \(eventCode)")
//    switch eventCode {
//    case Stream.Event.openCompleted:
//      if input?.streamStatus == .open && output?.streamStatus == .open,
//         input == aStream {
//        self.handshake.startHandShake()
//      }
//    case Stream.Event.hasBytesAvailable:
//      if aStream == input {
//        self.readData()
//      }
//    case Stream.Event.hasSpaceAvailable:
//      break
//    case Stream.Event.errorOccurred:
//      if let e = aStream.streamError {
//        print("[HPRTMP] error: \(e.localizedDescription)")
//
//        self.delegate?.socketError(self, err: .uknown(desc: e.localizedDescription))
//      }
//      self.invalidate()
//    case Stream.Event.endEncountered:
//      self.invalidate()
//    default: break
//    }
//  }
//}

extension RTMPSocket {
  func send(message: RTMPBaseMessageProtocol & Encodable, firstType: Bool = true) {
    if let message = message as? ChunkSizeMessage {
      encoder.chunkSize = message.size
    }
    self.sendChunk(encoder.chunk(message: message, isFirstType0: firstType))
  }
  
  private func sendChunk(_ data: [Data]) {
    data.forEach { [unowned self] in self.send($0) }
  }
}

extension RTMPSocket {
  private func handleOutputData(data: Data) {
    let length = data.count
    guard length > 0 else { return }
    if handshake.status == .handshakeDone {
      inputData.append(data)
      let bytes: Data = self.inputData
      self.inputData.removeAll()
      self.decode(data: bytes)
    } else {
      handshake.serverData.append(data)
    }
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
  
  func send(_ data: Data, complete: @escaping () -> Void = {}) {
    connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
      guard let self = self else { return }
      if let error = error {
        print("Error sending C2 bytes: \(error)")
        self.connection?.cancel()
        return
      }
      
      complete()
    }))
    
  }
}
