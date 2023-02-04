//
//  RTMPSocket.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import AVFoundation


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
  private var input: InputStream?
  private var output: OutputStream?
  private var runloop: RunLoop?
  
  private var buffer: UnsafeMutablePointer<UInt8>?
  private var inputData = Data()
  
  private var state: RTMPState = .none
  
  weak var delegate: RTMPSocketDelegate?
  
  let urlInfo: RTMPURLInfo
  
  var connectId: Int = 0
  
  private lazy var handshake: RTMPHandshake = {
    return RTMPHandshake(statusChange: { [weak self] (status) in
      guard let self = self else { return }
      print("[HPRTMP] handshake status: \(status)")
      switch status {
      case .uninitalized:
        self.send(self.handshake.c0c1Packet)
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
      Stream.getStreamsToHost(withName: urlInfo.host,
                              port: urlInfo.port,
                              inputStream: &self.input,
                              outputStream: &self.output)
      self.setParameter()
    }
  }
  
  public func invalidate() {
    guard state != .closed && state != .none else { return }
    self.clearParameter()
    handshake.reset()
    //        decoder.reset()
    //        encoder.reset()
    //        info.reset(clearInfo)
  }
  
  
}

// socket handling
extension RTMPSocket {
  func setParameter() {
    buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: RTMPSocket.maxReadSize)
    buffer?.initialize(repeating: 0, count: RTMPSocket.maxReadSize)
    self.input?.delegate = self
    self.output?.delegate = self
    
    self.runloop = .current
    self.input?.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
    self.input?.schedule(in: self.runloop!, forMode: RunLoop.Mode.default)
    self.input?.setProperty(StreamSocketSecurityLevel.none, forKey: .socketSecurityLevelKey)
    self.output?.schedule(in: self.runloop!, forMode: RunLoop.Mode.default)
    self.output?.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
    self.input?.open()
    self.output?.open()
    self.runloop?.run()
  }
  
  open func clearParameter() {
    self.input?.close()
    self.input?.remove(from: runloop!, forMode: RunLoop.Mode.default)
    self.input?.delegate = nil
    self.output?.close()
    self.output?.remove(from: runloop!, forMode: RunLoop.Mode.default)
    self.output?.delegate = nil
    self.input = nil
    self.output = nil
    buffer?.deinitialize(count: RTMPSocket.maxReadSize)
    buffer?.deallocate()
    buffer = nil
    inputData.removeAll()
    
    guard let r = self.runloop else {
      return
    }
    CFRunLoopStop(r.getCFRunLoop())
    self.runloop = nil
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


extension RTMPSocket: StreamDelegate {
  public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    print("[HPRTMP] stream \(aStream) eventCode: \(eventCode)")
    switch eventCode {
    case Stream.Event.openCompleted:
      if input?.streamStatus == .open && output?.streamStatus == .open,
         input == aStream {
        self.handshake.startHandShake()
      }
    case Stream.Event.hasBytesAvailable:
      if aStream == input {
        self.readData()
      }
    case Stream.Event.hasSpaceAvailable:
      break
    case Stream.Event.errorOccurred:
      if let e = aStream.streamError {
        print("[HPRTMP] error: \(e.localizedDescription)")
        
        self.delegate?.socketError(self, err: .uknown(desc: e.localizedDescription))
      }
      self.invalidate()
    case Stream.Event.endEncountered:
      self.invalidate()
    default: break
    }
  }
}

extension RTMPSocket {
  func send(message: RTMPBaseMessageProtocol & Encodable, firstType: Bool) {
    if let message = message as? ChunkSizeMessage {
      
    }
  }
  
}

extension RTMPSocket {
  private func readData() {
    guard let i = input, let b = buffer else {
      return
    }
    let length = i.read(b, maxLength: RTMPSocket.maxReadSize)
    guard length > 0 else { return }
    if self.handshake.status == .handshakeDone {
      //              inputData.append(b, count: length)
      //              let bytes:Data = self.inputData
      //              inputData.removeAll()
      //              self.decode(data: bytes)
    } else {
      handshake.serverData.append(Data(bytes: b, count: length))
    }
    
  }
  
  func send(_ data: Data) {
    outputQueue.async { [weak self] in
      guard let o = self?.output else {
        return
      }
      data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
        // Keep track of the total number of bytes written
        var total: Int = 0
        
        let bufferPoint = buffer.bindMemory(to: UInt8.self).baseAddress!
        // Write the data to the output stream in chunks
        while total < data.count {
          // Get the next chunk of data to write
          let length = o.write(bufferPoint.advanced(by: total),maxLength: data.count)
          
          // Check if the write was successful
          if length <= 0 {
            break
          }
          
          // Increment the total number of bytes written
          total += length
        }
      }
    }
  }
}
