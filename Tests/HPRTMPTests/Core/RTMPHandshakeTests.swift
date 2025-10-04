//
//  RTMPHandshakeTests.swift
//
//
//  Created by 郭 輝平 on 2023/03/15.
//

import XCTest
@testable import HPRTMP

actor MockNetworkClient: NetworkConnectable {
  private var dataSender: ((Data) -> Void)?
  private var dataReceiver: (() -> Data)?

  init(dataSender: ((Data) -> Void)? = nil, dataReceiver: (() -> Data)? = nil) {
    self.dataSender = dataSender
    self.dataReceiver = dataReceiver
  }

  func connect(host: String, port: Int) async throws {
    // Mock implementation
  }

  func sendData(_ data: Data) async throws {
    dataSender?(data)
  }

  func receiveData() async throws -> Data {
    return dataReceiver?() ?? Data()
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
  
  private func generateS1Packet() -> Data {
      var data = Data()
      
      // s1 timestamp
      let timestamp = UInt32(Date().timeIntervalSince1970).bigEndian
      data.write(timestamp)
      
      // s1 random data
      let randomSize = RTMPHandshake.packetSize - 4 // S1 timestamp is 4 bytes
      (0..<randomSize).forEach { _ in
          data.write(UInt8(arc4random_uniform(0xff)))
      }
      
      return data
  }
  func testC2Packet() async {
    let mockClient = MockNetworkClient()
    let handshake = RTMPHandshake(client: mockClient)

    let s1Packet = generateS1Packet()
    let c2Packet = await handshake.c2Packet(s0s1Packet: s1Packet)

    XCTAssertEqual(c2Packet.count, 1536, "C2 packet length is incorrect")

    let s1Timestamp = s1Packet.subdata(in: 0..<4)
    let c2Timestamp = c2Packet.subdata(in: 0..<4)

    XCTAssertEqual(c2Timestamp, Data(s1Timestamp), "C2 timestamp is incorrect")
    XCTAssertEqual(c2Packet.subdata(in: 8..<1536), s1Packet.subdata(in: 8..<RTMPHandshake.packetSize), "C2 random data is incorrect")
  }
}
