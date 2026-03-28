//
//  RTMPMediaEventTests.swift
//  HPRTMPTests
//
//  Tests for RTMPMediaEvent, RTMPStreamEvent, and RTMPConnectionEvent
//

import XCTest
@testable import HPRTMP

final class RTMPMediaEventTests: XCTestCase {

    // MARK: - RTMPMediaEvent Tests

    func testAudioEventCreation() {
        let audioData = Data([0x01, 0x02, 0x03])
        let timestamp: Int64 = 1000

        let event = RTMPMediaEvent.audio(data: audioData, timestamp: timestamp)

        if case .audio(let data, let ts) = event {
            XCTAssertEqual(data, audioData)
            XCTAssertEqual(ts, timestamp)
        } else {
            XCTFail("Expected audio event")
        }
    }

    func testVideoEventCreation() {
        let videoData = Data([0x00, 0x00, 0x00])
        let timestamp: Int64 = 2000

        let event = RTMPMediaEvent.video(data: videoData, timestamp: timestamp)

        if case .video(let data, let ts) = event {
            XCTAssertEqual(data, videoData)
            XCTAssertEqual(ts, timestamp)
        } else {
            XCTFail("Expected video event")
        }
    }

    func testMetadataEventCreation() {
        // MetaDataResponse requires a valid commandObject
        // Just verify the event case can be created without crashing
        let commandObject: [String: AMFValue] = ["duration": .double(0)]
        guard let metadata = MetaDataResponse(commandObject: commandObject) else {
            XCTFail("Failed to create MetaDataResponse")
            return
        }
        
        let event = RTMPMediaEvent.metadata(metadata)
        
        // Verify it's the correct event type
        switch event {
        case .metadata:
            // Success
            break
        default:
            XCTFail("Expected metadata event")
        }
    }

    func testMediaEventIsSendable() {
        // Compile-time check that RTMPMediaEvent is Sendable
        func assertSendable<T: Sendable>(_ value: T) {}
        
        let audioEvent = RTMPMediaEvent.audio(data: Data(), timestamp: 0)
        let videoEvent = RTMPMediaEvent.video(data: Data(), timestamp: 0)
        
        assertSendable(audioEvent)
        assertSendable(videoEvent)
        
        // Test metadata event if possible
        let commandObject: [String: AMFValue] = ["duration": .double(0)]
        if let metadata = MetaDataResponse(commandObject: commandObject) {
            let metadataEvent = RTMPMediaEvent.metadata(metadata)
            assertSendable(metadataEvent)
        }
    }

    // MARK: - RTMPStreamEvent Tests

    func testPublishStartEvent() {
        let event = RTMPStreamEvent.publishStart

        if case .publishStart = event {
            // Success
        } else {
            XCTFail("Expected publishStart event")
        }
    }

    func testPlayStartEvent() {
        let event = RTMPStreamEvent.playStart

        if case .playStart = event {
            // Success
        } else {
            XCTFail("Expected playStart event")
        }
    }

    func testRecordEvent() {
        let event = RTMPStreamEvent.record

        if case .record = event {
            // Success
        } else {
            XCTFail("Expected record event")
        }
    }

    func testPauseEvent() {
        let pausedEvent = RTMPStreamEvent.pause(true)
        let resumedEvent = RTMPStreamEvent.pause(false)

        if case .pause(let isPaused) = pausedEvent {
            XCTAssertTrue(isPaused)
        } else {
            XCTFail("Expected pause(true) event")
        }

        if case .pause(let isPaused) = resumedEvent {
            XCTAssertFalse(isPaused)
        } else {
            XCTFail("Expected pause(false) event")
        }
    }

    func testPingRequestEvent() {
        let pingData = Data([0x01, 0x02, 0x03, 0x04])
        let event = RTMPStreamEvent.pingRequest(pingData)

        if case .pingRequest(let data) = event {
            XCTAssertEqual(data, pingData)
        } else {
            XCTFail("Expected pingRequest event")
        }
    }

    func testStreamEventIsSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        
        let publishStart = RTMPStreamEvent.publishStart
        let playStart = RTMPStreamEvent.playStart
        let record = RTMPStreamEvent.record
        let pause = RTMPStreamEvent.pause(false)
        let ping = RTMPStreamEvent.pingRequest(Data())
        
        assertSendable(publishStart)
        assertSendable(playStart)
        assertSendable(record)
        assertSendable(pause)
        assertSendable(ping)
    }

    // MARK: - RTMPConnectionEvent Tests

    func testPeerBandwidthChangedEvent() {
        let bandwidth: UInt32 = 2500000
        let event = RTMPConnectionEvent.peerBandwidthChanged(bandwidth)

        if case .peerBandwidthChanged(let size) = event {
            XCTAssertEqual(size, bandwidth)
        } else {
            XCTFail("Expected peerBandwidthChanged event")
        }
    }

    func testDisconnectedEvent() {
        let event = RTMPConnectionEvent.disconnected

        if case .disconnected = event {
            // Success
        } else {
            XCTFail("Expected disconnected event")
        }
    }

    func testConnectionEventIsSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        
        let bandwidth = RTMPConnectionEvent.peerBandwidthChanged(0)
        let disconnected = RTMPConnectionEvent.disconnected
        
        assertSendable(bandwidth)
        assertSendable(disconnected)
    }
}
