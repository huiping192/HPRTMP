//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import os

protocol RTMPHandshakeDelegate: AnyObject {
  func rtmpHandshakeDidChange(status: RTMPHandshake.Status)
}

actor RTMPHandshake {
  enum Status: String {
    case uninitalized
    case verSent
    case ackSent
    case handshakeDone
    case none
  }
  
  // const 1536 byte
  static let packetSize = 1536
  private static let rtmpVersion: UInt8 = 3
  
  private let dataSender: (Data) async throws -> Void
  private let dataReceiver: () async throws -> Data
  
  weak var delegate: RTMPHandshakeDelegate?
  
  private let logger = Logger(subsystem: "HPRTMP", category: "Handshake")
  
  private var handshakeData = Data()
  
  public func setDelegate(delegate: RTMPHandshakeDelegate?) {
    self.delegate = delegate
  }
  
  public init(dataSender: @escaping (Data) async throws -> Void, dataReceiver: @escaping () async throws -> Data) {
    self.dataSender = dataSender
    self.dataReceiver = dataReceiver
  }
  
  private(set) var status = Status.none {
    didSet {
      logger.info("handshake status changed to \(self.status.rawValue) ")
      delegate?.rtmpHandshakeDidChange(status: status)
    }
  }
  
  var c0c1Packet: Data {
    var data = Data()
    
    // rtmp version
    data.write(RTMPHandshake.rtmpVersion)
    // time stamp
    data.write(UInt32(0).toUInt8Array())
    // const 0,0,0,0
    data.write([0x00,0x00,0x00,0x00])
    
    // random
    let randomSize = RTMPHandshake.packetSize - data.count
    (0...randomSize).forEach { _ in
      data.write(UInt8(arc4random_uniform(0xff)))
    }
    return data
  }
  
  func c2Packet(s0s1Packet: Data) -> Data {
    var data = Data()
    // s1 timestamp
    data.append(s0s1Packet.subdata(in: 0..<4))
    // timestamp
    data.write(UInt32(Date().timeIntervalSince1970).bigEndian.toUInt8Array())
    // c2 random
    data.append(s0s1Packet.subdata(in: 8..<RTMPHandshake.packetSize))
    return data
  }
  
  func reset() {
    self.status = .none
  }
  
  func start() async throws {
    status = .uninitalized
    
    // send c0c1 packet
    try await sendPacket(c0c1Packet)
        
    // receive s0s1, + 1 because first byte is s0(rtmp version)
    let s0s1Packet = try await receivePacket(expectedSize: Self.packetSize + 1)
   
    status = .verSent

    // send c2 packet
    try await sendPacket(c2Packet(s0s1Packet: s0s1Packet))
    
    status = .ackSent
    
    // receive s2 packet
    _ = try await receivePacket(expectedSize: Self.packetSize)
    
    status = .handshakeDone
  }
  
  private func sendPacket(_ packet: Data) async throws {
    try await dataSender(packet)
  }
  
  private func receivePacket(expectedSize: Int) async throws -> Data {
    while true {
      if handshakeData.count >= expectedSize {
        let receivedPacket = handshakeData.subdata(in: 0..<expectedSize)
        handshakeData.removeSubrange(0..<expectedSize)
        
        return receivedPacket
      }
      
      let data = try await dataReceiver()
      handshakeData.append(data)
    }
  }
}


