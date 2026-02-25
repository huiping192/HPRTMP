//
//  RTMPHandshakeTests.swift
//
//
//  Created by 郭 輝平 on 2023/03/15.
//

import XCTest
@testable import HPRTMP

actor MockNetworkClient: NetworkConnectable {
  private var receivedDataQueue: [Data] = []
  private var currentIndex = 0
  private(set) var sentPackets: [Data] = []

  func setReceivedDataQueue(_ queue: [Data]) {
    self.receivedDataQueue = queue
    self.currentIndex = 0
  }

  func connect(host: String, port: Int, enableTLS: Bool) async throws {
    // Mock implementation
  }

  func sendData(_ data: Data) async throws {
    sentPackets.append(data)
  }

  func receiveData() async throws -> Data {
    guard currentIndex < receivedDataQueue.count else {
      throw RTMPError.dataRetrievalFailed
    }

    let data = receivedDataQueue[currentIndex]
    currentIndex += 1
    return data
  }

  func close() async throws {
    // Mock implementation
  }
}

final class RTMPHandshakeTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testC0C1PacketLength() async {
    let mockClient = MockNetworkClient()
    let handshake = RTMPHandshake(client: mockClient)

    let c0c1Packet = await handshake.c0c1Packet
    let expectedLength = 1537 // C0 chunk size (1 byte) + C1 chunk size (1536 bytes)

    XCTAssertEqual(c0c1Packet.count, expectedLength, "C0/C1 packet length is incorrect")
  }
  
  /// Generate a complete S0S1 packet (S0: 1 byte + S1: 1536 bytes)
  private func generateS0S1Packet() -> Data {
      var data = Data()

      // S0: RTMP version (1 byte)
      data.write(UInt8(3))

      // S1: timestamp (4 bytes)
      let timestamp = UInt32(Date().timeIntervalSince1970).bigEndian
      data.write(timestamp)

      // S1: zero (4 bytes)
      data.write([0x00, 0x00, 0x00, 0x00])

      // S1: random data (1536 - 8 = 1528 bytes)
      let randomSize = RTMPHandshake.c1PacketSize - 8
      (0..<randomSize).forEach { _ in
          data.write(UInt8(arc4random_uniform(0xff)))
      }

      return data
  }
  
  func testC2Packet() async throws {
    let mockClient = MockNetworkClient()
    let handshake = RTMPHandshake(client: mockClient)

    // Generate a complete S0S1 packet
    let s0s1Packet = generateS0S1Packet()
    XCTAssertEqual(s0s1Packet.count, 1537, "S0S1 packet should be 1537 bytes")
    
    let c2Packet = try await handshake.c2Packet(s0s1Packet: s0s1Packet)

    XCTAssertEqual(c2Packet.count, 1536, "C2 packet length is incorrect")

    // Verify C2 contains S1's timestamp (bytes 1-4 of S0S1)
    let s1Timestamp = s0s1Packet.subdata(in: 1..<5)
    let c2Timestamp = c2Packet.subdata(in: 0..<4)
    XCTAssertEqual(c2Timestamp, s1Timestamp, "C2 should echo S1 timestamp")
    
    // Verify C2 contains S1's random data (bytes 9-1536 of S0S1)
    let s1RandomData = s0s1Packet.subdata(in: 9..<1537)
    let c2RandomData = c2Packet.subdata(in: 8..<1536)
    XCTAssertEqual(c2RandomData, s1RandomData, "C2 should echo S1 random data")
  }

  func testC2PacketWithInvalidS0S1Size() async {
    let mockClient = MockNetworkClient()
    let handshake = RTMPHandshake(client: mockClient)

    let invalidS0S1 = Data(count: 100) // Too short

    do {
      _ = try await handshake.c2Packet(s0s1Packet: invalidS0S1)
      XCTFail("Should throw error for invalid S0S1 packet size")
    } catch RTMPError.handShake(let desc) {
      XCTAssertTrue(desc.contains("Invalid S0S1 packet size"))
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testReset() async {
    let mockClient = MockNetworkClient()
    let handshake = RTMPHandshake(client: mockClient)

    await handshake.reset()

    let status = await handshake.status
    XCTAssertEqual(status, .none, "Status should be reset to .none")
  }

  func testCompleteHandshakeFlow() async throws {
    let mockClient = MockNetworkClient()

    // Generate S0S1 response (S0: 1 byte + S1: 1536 bytes)
    var s0s1 = Data()
    s0s1.write(UInt8(3)) // S0: RTMP version
    s0s1.write(UInt32(0).toUInt8Array()) // S1 timestamp
    s0s1.write([0x00, 0x00, 0x00, 0x00]) // S1 zero
    let s1RandomSize = RTMPHandshake.c1PacketSize - 8
    s0s1.append(contentsOf: (0..<s1RandomSize).map { _ in UInt8.random(in: 0...255) })

    // Generate S2 response (1536 bytes)
    var s2 = Data()
    s2.write(UInt32(0).toUInt8Array()) // timestamp
    s2.write(UInt32(0).toUInt8Array()) // timestamp2
    let s2RandomSize = RTMPHandshake.c1PacketSize - 8
    s2.append(contentsOf: (0..<s2RandomSize).map { _ in UInt8.random(in: 0...255) })

    // Setup mock to return S0S1 then S2
    await mockClient.setReceivedDataQueue([s0s1, s2])

    let handshake = RTMPHandshake(client: mockClient)

    // Perform handshake
    try await handshake.start()

    // Verify status
    let finalStatus = await handshake.status
    XCTAssertEqual(finalStatus, .handshakeDone, "Handshake should complete successfully")

    // Verify sent packets
    let sentPackets = await mockClient.sentPackets
    XCTAssertEqual(sentPackets.count, 2, "Should send C0C1 and C2")
    XCTAssertEqual(sentPackets[0].count, 1537, "C0C1 packet should be 1537 bytes")
    XCTAssertEqual(sentPackets[1].count, 1536, "C2 packet should be 1536 bytes")
  }
}
