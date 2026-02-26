//
//  RTMPEventDispatcherTests.swift
//
//
//  Created by Huiping Guo on 2026/02/26.
//

import XCTest
@testable import HPRTMP

final class RTMPEventDispatcherTests: XCTestCase {

  // MARK: - Helpers

  private func makeDispatcher() -> (
    dispatcher: RTMPEventDispatcher,
    mediaStream: AsyncStream<RTMPMediaEvent>,
    streamStream: AsyncStream<RTMPStreamEvent>,
    connectionStream: AsyncStream<RTMPConnectionEvent>
  ) {
    let (mediaStream, mediaCont) = AsyncStream<RTMPMediaEvent>.makeStream()
    let (streamStream, streamCont) = AsyncStream<RTMPStreamEvent>.makeStream()
    let (connectionStream, connCont) = AsyncStream<RTMPConnectionEvent>.makeStream()

    let dispatcher = RTMPEventDispatcher(
      mediaContinuation: mediaCont,
      streamContinuation: streamCont,
      connectionContinuation: connCont
    )

    return (dispatcher, mediaStream, streamStream, connectionStream)
  }

  // MARK: - Yield Tests

  func testYieldMediaEventIsReceived() async throws {
    let (dispatcher, mediaStream, _, _) = makeDispatcher()

    await dispatcher.yieldMedia(.audio(data: Data([0x01]), timestamp: 100))

    var received: RTMPMediaEvent?
    for await event in mediaStream {
      received = event
      break
    }

    guard case .audio(let data, let timestamp) = received else {
      XCTFail("Expected audio event")
      return
    }
    XCTAssertEqual(data, Data([0x01]))
    XCTAssertEqual(timestamp, 100)
  }

  func testYieldStreamEventIsReceived() async throws {
    let (dispatcher, _, streamStream, _) = makeDispatcher()

    await dispatcher.yieldStream(.publishStart)

    var received: RTMPStreamEvent?
    for await event in streamStream {
      received = event
      break
    }

    guard case .publishStart = received else {
      XCTFail("Expected publishStart event")
      return
    }
  }

  func testYieldConnectionEventIsReceived() async throws {
    let (dispatcher, _, _, connectionStream) = makeDispatcher()

    await dispatcher.yieldConnection(.disconnected)

    var received: RTMPConnectionEvent?
    for await event in connectionStream {
      received = event
      break
    }

    guard case .disconnected = received else {
      XCTFail("Expected disconnected event")
      return
    }
  }

  // MARK: - Finish Tests

  /// Critical: after finish(), all `for await` loops must terminate.
  /// Without this, tasks waiting on these streams would leak after invalidate().
  func testFinishTerminatesAllStreams() async throws {
    let (dispatcher, mediaStream, streamStream, connectionStream) = makeDispatcher()

    await dispatcher.finish()

    // Each task returns true when its loop exits; false if it somehow hangs (test timeout)
    let results = await withTaskGroup(of: (String, Bool).self) { group in
      group.addTask {
        for await _ in mediaStream {}
        return ("media", true)
      }
      group.addTask {
        for await _ in streamStream {}
        return ("stream", true)
      }
      group.addTask {
        for await _ in connectionStream {}
        return ("connection", true)
      }
      var collected: [String: Bool] = [:]
      for await (name, terminated) in group {
        collected[name] = terminated
      }
      return collected
    }

    XCTAssertTrue(results["media"] == true, "mediaStream for-await loop must terminate after finish()")
    XCTAssertTrue(results["stream"] == true, "streamStream for-await loop must terminate after finish()")
    XCTAssertTrue(results["connection"] == true, "connectionStream for-await loop must terminate after finish()")
  }

  /// Events yielded before finish() must be received, and the loop must still terminate.
  func testEventsBeforeFinishAreReceivedThenLoopTerminates() async throws {
    let (dispatcher, _, _, connectionStream) = makeDispatcher()

    await dispatcher.yieldConnection(.disconnected)
    await dispatcher.yieldConnection(.peerBandwidthChanged(1024))
    await dispatcher.finish()

    var events: [RTMPConnectionEvent] = []
    for await event in connectionStream {
      events.append(event)
    }
    // Loop must have terminated (not hung)

    XCTAssertEqual(events.count, 2)
    guard case .disconnected = events[0] else {
      XCTFail("First event must be .disconnected")
      return
    }
    guard case .peerBandwidthChanged(let size) = events[1] else {
      XCTFail("Second event must be .peerBandwidthChanged")
      return
    }
    XCTAssertEqual(size, 1024)
  }

  /// finish() must be idempotent — calling it twice must not crash.
  func testFinishIsIdempotent() async throws {
    let (dispatcher, _, _, _) = makeDispatcher()

    await dispatcher.finish()
    await dispatcher.finish()  // Should not crash
  }

  /// After finish(), yielding events is a no-op (not a crash).
  func testYieldAfterFinishIsNoOp() async throws {
    let (dispatcher, _, _, connectionStream) = makeDispatcher()

    await dispatcher.finish()
    await dispatcher.yieldConnection(.disconnected)  // Should not crash

    var events: [RTMPConnectionEvent] = []
    for await event in connectionStream {
      events.append(event)
    }

    XCTAssertTrue(events.isEmpty, "No events should be received after finish()")
  }
}
