//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import os

actor RTMPHandshake {
  enum Status: String {
    case uninitalized
    case verSent
    case ackSent
    case handshakeDone
    case none
  }

  // C1 packet size (1536 bytes, not including C0)
  static let c1PacketSize = 1536
  private static let rtmpVersion: UInt8 = 3
  private static let maxBufferSize = 1024 * 1024 // 1MB

  private let client: any NetworkConnectable

  private let logger = Logger(subsystem: "HPRTMP", category: "Handshake")

  private var handshakeData = Data()

  private(set) var status = Status.none {
    didSet {
      logger.info("handshake status changed to \(self.status.rawValue)")
    }
  }

  public init(client: any NetworkConnectable) {
    self.client = client
  }
  
  var c0c1Packet: Data {
    var data = Data()
    
    // rtmp version
    data.write(RTMPHandshake.rtmpVersion)
    // time stamp
    data.write(UInt32(0).toUInt8Array())
    // const 0,0,0,0
    data.write([0x00,0x00,0x00,0x00])
    
    // random bytes: C1 size minus already written bytes (version + timestamp + zero)
    // Note: using 0...randomSize because we need randomSize+1 bytes to reach total C1 size
    let randomSize = RTMPHandshake.c1PacketSize - data.count
    data.append(contentsOf: (0...randomSize).map { _ in UInt8.random(in: 0...255) })
    
    return data
  }
  
  func c2Packet(s0s1Packet: Data) throws -> Data {
    guard s0s1Packet.count >= Self.c1PacketSize else {
      throw RTMPError.handShake(desc: "Invalid S0S1 packet size: \(s0s1Packet.count)")
    }

    var data = Data()
    // s1 timestamp
    data.append(s0s1Packet.subdata(in: 0..<4))
    // timestamp
    data.write(UInt32(Date().timeIntervalSince1970).bigEndian.toUInt8Array())
    // c2 random
    data.append(s0s1Packet.subdata(in: 8..<RTMPHandshake.c1PacketSize))
    return data
  }
  
  func reset() {
    status = .none
    handshakeData.removeAll()
  }

  func start() async throws {
    status = .uninitalized

    // send c0c1 packet
    try await sendPacket(c0c1Packet)

    // receive s0s1, + 1 because first byte is s0(rtmp version)
    let s0s1Packet = try await receivePacket(expectedSize: Self.c1PacketSize + 1)

    status = .verSent

    // send c2 packet
    try await sendPacket(try c2Packet(s0s1Packet: s0s1Packet))

    status = .ackSent

    // receive s2 packet
    _ = try await receivePacket(expectedSize: Self.c1PacketSize)

    status = .handshakeDone
  }
  
  private func sendPacket(_ packet: Data) async throws {
    try await client.sendData(packet)
  }

  private func receivePacket(expectedSize: Int) async throws -> Data {
    while true {
      if handshakeData.count >= expectedSize {
        let receivedPacket = handshakeData.subdata(in: 0..<expectedSize)
        handshakeData.removeSubrange(0..<expectedSize)

        return receivedPacket
      }

      guard handshakeData.count < Self.maxBufferSize else {
        throw RTMPError.bufferOverflow
      }

      let data = try await client.receiveData()
      handshakeData.append(data)
    }
  }
}


