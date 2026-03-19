//
//  RTMPHandshake.swift
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

  // C0 packet size (1 byte: RTMP version)
  private static let c0PacketSize = 1
  // C1 packet size (1536 bytes, not including C0)
  static let c1PacketSize = 1536
  // S1 packet structure offsets
  private static let s1TimestampOffset = c0PacketSize // S1 starts after S0
  private static let s1TimestampSize = 4
  private static let s1ZeroOffset = s1TimestampOffset + s1TimestampSize
  private static let s1ZeroSize = 4
  private static let s1RandomOffset = s1ZeroOffset + s1ZeroSize
  
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
    
    // C0: RTMP version (1 byte)
    data.write(RTMPHandshake.rtmpVersion)
    
    // C1: timestamp (4 bytes)
    data.write(UInt32(0).toUInt8Array())
    
    // C1: zero (4 bytes)
    data.write([0x00, 0x00, 0x00, 0x00])
    
    // C1: random bytes to fill remaining space
    // Total size should be C0 (1) + C1 (1536) = 1537 bytes
    let totalSize = Self.c0PacketSize + Self.c1PacketSize
    let randomSize = totalSize - data.count
    data.append(contentsOf: (0..<randomSize).map { _ in UInt8.random(in: 0...255) })
    
    return data
  }
  
  func c2Packet(s0s1Packet: Data) throws -> Data {
    // S0S1 packet should contain S0 (1 byte) + S1 (1536 bytes)
    let expectedSize = Self.c0PacketSize + Self.c1PacketSize
    guard s0s1Packet.count >= expectedSize else {
      throw RTMPError.handShake(desc: "Invalid S0S1 packet size: \(s0s1Packet.count), expected at least \(expectedSize)")
    }

    var data = Data()
    
    // C2: S1 timestamp (4 bytes, starting after S0)
    let timestampStart = Self.s1TimestampOffset
    let timestampEnd = timestampStart + Self.s1TimestampSize
    data.append(s0s1Packet.subdata(in: timestampStart..<timestampEnd))
    
    // C2: current timestamp (4 bytes)
    data.write(UInt32(Date().timeIntervalSince1970).bigEndian.toUInt8Array())
    
    // C2: S1 random data (starting from S1's random offset)
    let randomStart = Self.s1RandomOffset
    let randomEnd = Self.c0PacketSize + Self.c1PacketSize
    data.append(s0s1Packet.subdata(in: randomStart..<randomEnd))
    
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


