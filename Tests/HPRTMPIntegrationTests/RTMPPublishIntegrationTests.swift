import XCTest
import HPRTMP

final class RTMPPublishIntegrationTests: XCTestCase {

  private let testURL = IntegrationTestConfig.rtmpTestURL
  private let timeout: TimeInterval = 10

  // Minimal PublishConfigure for synthetic data tests
  private let configure = PublishConfigure(
    width: 640,
    height: 480,
    videocodecid: 7,  // H.264
    audiocodecid: 10, // AAC
    framerate: 30
  )

  // Synthetic AVC sequence header (minimal valid structure for testing)
  private var syntheticVideoHeader: Data {
    // FLV VideoTagHeader: FrameType=1 (keyframe), CodecID=7 (AVC)
    // AVCPacketType=0 (sequence header), CompositionTime=0
    var data = Data([0x17, 0x00, 0x00, 0x00, 0x00])
    // AVCDecoderConfigurationRecord (minimal)
    data.append(contentsOf: [
      0x01,       // configurationVersion
      0x42, 0x00, 0x1e, // profile_idc, profile_compatibility, level_idc
      0xFF,       // 6 reserved bits + lengthSizeMinusOne
      0xE1,       // 3 reserved bits + numSequenceParameterSets
      0x00, 0x04, // SPS length
      0x67, 0x42, 0x00, 0x1e, // SPS NAL unit (minimal)
      0x01,       // numPictureParameterSets
      0x00, 0x04, // PPS length
      0x68, 0xce, 0x38, 0x80  // PPS NAL unit (minimal)
    ])
    return data
  }

  // Synthetic AAC sequence header
  private var syntheticAudioHeader: Data {
    // FLV AudioTagHeader: SoundFormat=10 (AAC), SoundRate=3 (44kHz), SoundSize=1, SoundType=1
    // AACPacketType=0 (sequence header)
    var data = Data([0xAF, 0x00])
    // AudioSpecificConfig: AAC-LC, 44100 Hz, Stereo
    data.append(contentsOf: [0x12, 0x10])
    return data
  }

  // Synthetic H.264 P-frame
  private var syntheticVideoFrame: Data {
    var data = Data([0x27, 0x01, 0x00, 0x00, 0x00]) // non-keyframe, AVC NALU
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x05]) // NALU length = 5
    data.append(contentsOf: [0x41, 0x9A, 0x00, 0x00, 0x00]) // P-slice NALU
    return data
  }

  // Synthetic AAC audio frame
  private var syntheticAudioFrame: Data {
    var data = Data([0xAF, 0x01]) // AAC raw
    data.append(contentsOf: [0x21, 0x14, 0x00, 0x00, 0x00, 0x00]) // minimal AAC payload
    return data
  }

  // MARK: - Tests

  func testConnectAndPublishStart() async throws {
    try await skipIfNoRTMPServer()

    let session = RTMPPublishSession()
    defer { Task { await session.stop() } }

    let publishStartExpectation = expectation(description: "publishStart received")

    let statusTask = Task {
      for await status in await session.statusStream {
        if status == .publishStart {
          publishStartExpectation.fulfill()
          return
        }
        if case .failed = status {
          publishStartExpectation.fulfill()
          return
        }
      }
    }
    defer { statusTask.cancel() }

    await session.publish(url: testURL, configure: configure)

    await fulfillment(of: [publishStartExpectation], timeout: timeout)

    let finalStatus = await session.publishStatus
    XCTAssertEqual(finalStatus, .publishStart, "Expected publishStart, got \(finalStatus)")
  }

  func testPublishVideoAndAudio() async throws {
    try await skipIfNoRTMPServer()

    let session = RTMPPublishSession()
    defer { Task { await session.stop() } }

    // Wait for publishStart
    let publishStartExpectation = expectation(description: "publishStart")
    let statusTask = Task {
      for await status in await session.statusStream {
        if status == .publishStart {
          publishStartExpectation.fulfill()
          return
        }
        if case .failed = status { return }
      }
    }
    defer { statusTask.cancel() }

    await session.publish(url: testURL, configure: configure)
    await fulfillment(of: [publishStartExpectation], timeout: timeout)

    guard await session.publishStatus == .publishStart else {
      XCTFail("Did not reach publishStart")
      return
    }

    // Send synthetic media headers + frames
    await session.publishVideoHeader(data: syntheticVideoHeader)
    await session.publishAudioHeader(data: syntheticAudioHeader)

    for i in 0..<5 {
      let delta = UInt32(33) // ~30fps
      await session.publishVideo(data: syntheticVideoFrame, delta: i == 0 ? 0 : delta)
      await session.publishAudio(data: syntheticAudioFrame, delta: i == 0 ? 0 : delta)
    }

    // Give server time to register the stream
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

    // Parse app and stream from URL and verify via HTTP API when available
    let urlComponents = parseRTMPURL(testURL)
    switch await verifyStreamActive(app: urlComponents.app, stream: urlComponents.stream) {
    case .some(true):
      break // Stream confirmed active
    case .some(false):
      XCTFail("Stream should be active on Node-Media-Server")
    case nil:
      // HTTP API not available (e.g. unauthorized) — rely on publishStart status instead
      break
    }
  }

  func testGracefulStop() async throws {
    try await skipIfNoRTMPServer()

    let session = RTMPPublishSession()

    let publishStartExpectation = expectation(description: "publishStart")
    let disconnectedExpectation = expectation(description: "disconnected")

    let statusTask = Task {
      for await status in await session.statusStream {
        switch status {
        case .publishStart:
          publishStartExpectation.fulfill()
        case .disconnected:
          disconnectedExpectation.fulfill()
          return
        case .failed:
          disconnectedExpectation.fulfill()
          return
        default:
          break
        }
      }
    }
    defer { statusTask.cancel() }

    await session.publish(url: testURL, configure: configure)
    await fulfillment(of: [publishStartExpectation], timeout: timeout)

    await session.stop()
    await fulfillment(of: [disconnectedExpectation], timeout: timeout)

    let finalStatus = await session.publishStatus
    XCTAssertEqual(finalStatus, .disconnected)
  }

  func testReconnect() async throws {
    try await skipIfNoRTMPServer()

    let session = RTMPPublishSession()

    // First publish
    let firstPublishStart = expectation(description: "first publishStart")
    let statusTask1 = Task {
      for await status in await session.statusStream {
        if status == .publishStart {
          firstPublishStart.fulfill()
          return
        }
        if case .failed = status { firstPublishStart.fulfill(); return }
      }
    }
    defer { statusTask1.cancel() }

    await session.publish(url: testURL, configure: configure)
    await fulfillment(of: [firstPublishStart], timeout: timeout)

    await session.stop()
    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

    // Second publish — new statusStream after stop
    let secondPublishStart = expectation(description: "second publishStart")
    let statusTask2 = Task {
      for await status in await session.statusStream {
        if status == .publishStart {
          secondPublishStart.fulfill()
          return
        }
        if case .failed = status { secondPublishStart.fulfill(); return }
      }
    }
    defer { statusTask2.cancel() }

    await session.publish(url: testURL, configure: configure)
    await fulfillment(of: [secondPublishStart], timeout: timeout)

    let finalStatus = await session.publishStatus
    XCTAssertEqual(finalStatus, .publishStart, "Should reconnect successfully")

    await session.stop()
  }

  func testPublishRealMP4() async throws {
    try await skipIfNoRTMPServer()

    guard let mp4URL = Bundle.module.url(forResource: "test", withExtension: "mp4") else {
      XCTFail("test.mp4 not found in test bundle")
      return
    }

    let session = RTMPPublishSession()
    defer { Task { await session.stop() } }

    let publishStartExpectation = expectation(description: "publishStart")
    let statusTask = Task {
      for await status in await session.statusStream {
        if status == .publishStart {
          publishStartExpectation.fulfill()
          return
        }
        if case .failed = status { return }
      }
    }
    defer { statusTask.cancel() }

    let mp4Configure = PublishConfigure(
      width: 160, height: 120,
      videocodecid: VideoData.CodecId.avc.rawValue,
      audiocodecid: AudioData.SoundFormat.aac.rawValue,
      framerate: 15
    )
    await session.publish(url: testURL, configure: mp4Configure)
    await fulfillment(of: [publishStartExpectation], timeout: timeout)

    guard await session.publishStatus == .publishStart else {
      XCTFail("Did not reach publishStart")
      return
    }

    let mp4StoppedExpectation = expectation(description: "mp4 reading completed")
    let delegate = TestMP4Delegate(session: session) {
      mp4StoppedExpectation.fulfill()
    }

    let reader = MP4Reader(url: mp4URL)
    await reader.setDelegate(delegate)
    await reader.start()

    await fulfillment(of: [mp4StoppedExpectation], timeout: 15)

    try await Task.sleep(nanoseconds: 500_000_000)

    let urlComponents = parseRTMPURL(testURL)
    switch await verifyStreamActive(app: urlComponents.app, stream: urlComponents.stream) {
    case .some(true):
      break
    case .some(false):
      XCTFail("Stream should be active on Node-Media-Server")
    case nil:
      break
    }
  }

  func testInvalidURL() async throws {
    let session = RTMPPublishSession()
    defer { Task { await session.stop() } }

    let failedExpectation = expectation(description: "failed status")

    let statusTask = Task {
      for await status in await session.statusStream {
        if case .failed = status {
          failedExpectation.fulfill()
          return
        }
      }
    }
    defer { statusTask.cancel() }

    await session.publish(url: "rtmp://invalid-host-that-does-not-exist.local:1935/live/test", configure: configure)
    await fulfillment(of: [failedExpectation], timeout: timeout)

    let finalStatus = await session.publishStatus
    if case .failed = finalStatus {
      // Expected
    } else {
      XCTFail("Expected .failed status, got \(finalStatus)")
    }
  }
}

// MARK: - TestMP4Delegate

private actor TestMP4Delegate: MP4ReaderDelegate {
  private let session: RTMPPublishSession
  private let onStopped: @Sendable () -> Void
  private var lastVideoTimestamp: UInt64 = 0
  private var lastAudioTimestamp: UInt64 = 0

  init(session: RTMPPublishSession, onStopped: @escaping @Sendable () -> Void) {
    self.session = session
    self.onStopped = onStopped
  }

  func output(reader: MP4Reader, videoHeader: Data) async {
    await session.publishVideoHeader(data: videoHeader)
  }

  func output(reader: MP4Reader, audioHeader: Data) async {
    await session.publishAudioHeader(data: audioHeader)
  }

  func output(reader: MP4Reader, videoFrame: VideoFrame) async {
    let frameType = videoFrame.isKeyframe ? VideoData.FrameType.keyframe : VideoData.FrameType.inter
    var descData = Data([UInt8(frameType.rawValue << 4 | VideoData.CodecId.avc.rawValue),
                         VideoData.AVCPacketType.nalu.rawValue])
    let compositionTime = Int32(videoFrame.pts &- videoFrame.dts)
    descData.write24(compositionTime, bigEndian: true)
    descData.append(videoFrame.data)

    let delta = UInt32(videoFrame.dts &- lastVideoTimestamp)
    await session.publishVideo(data: descData, delta: delta)
    lastVideoTimestamp = videoFrame.dts
  }

  func output(reader: MP4Reader, audioFrame: AudioFrame) async {
    var audioPacketData = Data()
    audioPacketData.append(audioFrame.adtsHeader)
    audioPacketData.write(AudioData.AACPacketType.raw.rawValue)
    audioPacketData.append(audioFrame.data)

    let delta = UInt32(audioFrame.pts &- lastAudioTimestamp)
    await session.publishAudio(data: audioPacketData, delta: delta)
    lastAudioTimestamp = audioFrame.pts
  }

  func output(stopped reader: MP4Reader) async {
    onStopped()
  }
}

// MARK: - Helpers

private func parseRTMPURL(_ urlString: String) -> (app: String, stream: String) {
  // rtmp://host:port/app/stream  →  ("app", "stream")
  guard let url = URL(string: urlString) else { return ("live", "test") }
  let pathComponents = url.pathComponents.filter { $0 != "/" }
  let app = pathComponents.count > 0 ? pathComponents[0] : "live"
  let stream = pathComponents.count > 1 ? pathComponents[1] : "test"
  return (app, stream)
}
