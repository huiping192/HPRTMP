import XCTest
import HPRTMP

final class RTMPRoundtripIntegrationTests: XCTestCase {

  private let timeout: TimeInterval = 15

  private let configure = PublishConfigure(
    width: 640,
    height: 480,
    videocodecid: 7,
    audiocodecid: 10,
    framerate: 30
  )

  // Synthetic AVC sequence header
  private var syntheticVideoHeader: Data {
    var data = Data([0x17, 0x00, 0x00, 0x00, 0x00])
    data.append(contentsOf: [
      0x01, 0x42, 0x00, 0x1e, 0xFF, 0xE1,
      0x00, 0x04, 0x67, 0x42, 0x00, 0x1e,
      0x01, 0x00, 0x04, 0x68, 0xce, 0x38, 0x80
    ])
    return data
  }

  // Synthetic AAC sequence header
  private var syntheticAudioHeader: Data {
    var data = Data([0xAF, 0x00])
    data.append(contentsOf: [0x12, 0x10])
    return data
  }

  // Synthetic H.264 P-frame
  private var syntheticVideoFrame: Data {
    var data = Data([0x27, 0x01, 0x00, 0x00, 0x00])
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x05, 0x41, 0x9A, 0x00, 0x00, 0x00])
    return data
  }

  // Synthetic AAC audio frame
  private var syntheticAudioFrame: Data {
    var data = Data([0xAF, 0x01])
    data.append(contentsOf: [0x21, 0x14, 0x00, 0x00, 0x00, 0x00])
    return data
  }

  // MARK: - Test A: Synthetic Data Roundtrip

  func testRoundtripSyntheticData() async throws {
    try await skipIfNoRTMPServer()

    let streamURL = uniqueStreamURL(prefix: "roundtrip")

    // --- Publisher ---
    let publisher = RTMPPublishSession()
    defer { Task { await publisher.stop() } }

    let publishStartExp = expectation(description: "publishStart")
    let pubStatusTask = Task {
      for await status in await publisher.statusStream {
        if status == .publishStart { publishStartExp.fulfill(); return }
        if case .failed = status { publishStartExp.fulfill(); return }
      }
    }
    defer { pubStatusTask.cancel() }

    await publisher.publish(url: streamURL, configure: configure)
    await fulfillment(of: [publishStartExp], timeout: timeout)

    guard await publisher.publishStatus == .publishStart else {
      XCTFail("Publisher did not reach publishStart")
      return
    }

    // --- Player ---
    let player = RTMPPlayerSession()
    defer { Task { await player.stop() } }

    let playStartExp = expectation(description: "playStart")
    let playerStatusTask = Task {
      for await status in await player.statusStream {
        if status == .playStart { playStartExp.fulfill(); return }
        if case .failed = status { playStartExp.fulfill(); return }
      }
    }
    defer { playerStatusTask.cancel() }

    await player.play(url: streamURL)

    // --- Collector ---
    let collector = MediaCollector()
    await collector.startCollecting(from: player)
    defer { Task { await collector.stopCollecting() } }

    await fulfillment(of: [playStartExp], timeout: timeout)

    guard await player.status == .playStart else {
      XCTFail("Player did not reach playStart")
      return
    }

    // --- Send headers + 30 frames ---
    let frameCount = 30
    var sentVideoFrames: [Data] = []
    var sentAudioFrames: [Data] = []

    await publisher.publishVideoHeader(data: syntheticVideoHeader)
    await publisher.publishAudioHeader(data: syntheticAudioHeader)

    for i in 0..<frameCount {
      let delta = UInt32(i == 0 ? 0 : 33)
      await publisher.publishVideo(data: syntheticVideoFrame, delta: delta)
      await publisher.publishAudio(data: syntheticAudioFrame, delta: delta)
      sentVideoFrames.append(syntheticVideoFrame)
      sentAudioFrames.append(syntheticAudioFrame)
      try await Task.sleep(nanoseconds: 30_000_000) // ~30ms
    }

    // --- Wait for collector to receive enough frames (timeout 10s) ---
    let minExpected = frameCount / 2
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      let vCount = await collector.videoFrames.count
      let aCount = await collector.audioFrames.count
      if vCount >= minExpected && aCount >= minExpected { break }
      try await Task.sleep(nanoseconds: 200_000_000)
    }

    let receivedVideo = await collector.videoFrames
    let receivedAudio = await collector.audioFrames

    // --- Assertions ---
    XCTAssertGreaterThanOrEqual(
      receivedVideo.count, minExpected,
      "Received \(receivedVideo.count) video frames, expected >= \(minExpected)"
    )
    XCTAssertGreaterThanOrEqual(
      receivedAudio.count, minExpected,
      "Received \(receivedAudio.count) audio frames, expected >= \(minExpected)"
    )

    // First video frame must be the sequence header (0x17 0x00)
    if let firstVideo = receivedVideo.first {
      XCTAssertTrue(
        firstVideo.0.starts(with: [0x17, 0x00]),
        "First video frame should be AVC sequence header"
      )
    }

    // First audio frame must be the AAC sequence header (0xAF 0x00)
    if let firstAudio = receivedAudio.first {
      XCTAssertTrue(
        firstAudio.0.starts(with: [0xAF, 0x00]),
        "First audio frame should be AAC sequence header"
      )
    }

    // Payload frames after headers must match sent data
    let videoDataFrames = receivedVideo.dropFirst() // skip header
    let audioDataFrames = receivedAudio.dropFirst()

    for (received, sent) in zip(videoDataFrames, sentVideoFrames) {
      XCTAssertEqual(received.0, sent, "Video frame payload mismatch")
    }
    for (received, sent) in zip(audioDataFrames, sentAudioFrames) {
      XCTAssertEqual(received.0, sent, "Audio frame payload mismatch")
    }

    // Timestamps must be monotonically increasing
    assertMonotonicallyIncreasing(receivedVideo.map { $0.1 }, label: "video")
    assertMonotonicallyIncreasing(receivedAudio.map { $0.1 }, label: "audio")
  }

  // MARK: - Test B: Real MP4 Roundtrip

  func testRoundtripRealMP4() async throws {
    try await skipIfNoRTMPServer()

    guard let mp4URL = Bundle.module.url(forResource: "test", withExtension: "mp4") else {
      XCTFail("test.mp4 not found in test bundle")
      return
    }

    let streamURL = uniqueStreamURL(prefix: "mp4trip")

    // --- Publisher ---
    let publisher = RTMPPublishSession()
    defer { Task { await publisher.stop() } }

    let publishStartExp = expectation(description: "publishStart")
    let pubStatusTask = Task {
      for await status in await publisher.statusStream {
        if status == .publishStart { publishStartExp.fulfill(); return }
        if case .failed = status { publishStartExp.fulfill(); return }
      }
    }
    defer { pubStatusTask.cancel() }

    let mp4Configure = PublishConfigure(
      width: 160, height: 120,
      videocodecid: VideoData.CodecId.avc.rawValue,
      audiocodecid: AudioData.SoundFormat.aac.rawValue,
      framerate: 15
    )
    await publisher.publish(url: streamURL, configure: mp4Configure)
    await fulfillment(of: [publishStartExp], timeout: timeout)

    guard await publisher.publishStatus == .publishStart else {
      XCTFail("Publisher did not reach publishStart")
      return
    }

    // --- Player ---
    let player = RTMPPlayerSession()
    defer { Task { await player.stop() } }

    let playStartExp = expectation(description: "playStart")
    let playerStatusTask = Task {
      for await status in await player.statusStream {
        if status == .playStart { playStartExp.fulfill(); return }
        if case .failed = status { playStartExp.fulfill(); return }
      }
    }
    defer { playerStatusTask.cancel() }

    await player.play(url: streamURL)

    // --- Collector ---
    let collector = MediaCollector()
    await collector.startCollecting(from: player)
    defer { Task { await collector.stopCollecting() } }

    await fulfillment(of: [playStartExp], timeout: timeout)

    guard await player.status == .playStart else {
      XCTFail("Player did not reach playStart")
      return
    }

    // --- Publish MP4 via delegate, record sent data ---
    let mp4StoppedExp = expectation(description: "mp4 stopped")
    let recordingDelegate = RecordingMP4Delegate(session: publisher) {
      mp4StoppedExp.fulfill()
    }

    let reader = MP4Reader(url: mp4URL)
    await reader.setDelegate(recordingDelegate)
    await reader.start()

    await fulfillment(of: [mp4StoppedExp], timeout: 20)

    // Give player time to receive remaining frames
    try await Task.sleep(nanoseconds: 2_000_000_000)

    let sentVideo = await recordingDelegate.sentVideoFrames
    let sentAudio = await recordingDelegate.sentAudioFrames
    let sentVideoHeader = await recordingDelegate.sentVideoHeader
    let sentAudioHeader = await recordingDelegate.sentAudioHeader

    let receivedVideo = await collector.videoFrames
    let receivedAudio = await collector.audioFrames

    // At least some frames should have been received
    XCTAssertFalse(receivedVideo.isEmpty, "Should receive at least one video frame")
    XCTAssertFalse(receivedAudio.isEmpty, "Should receive at least one audio frame")

    // Header consistency
    if let sentVH = sentVideoHeader, let firstReceivedV = receivedVideo.first {
      XCTAssertEqual(firstReceivedV.0, sentVH, "Video header roundtrip mismatch")
    }
    if let sentAH = sentAudioHeader, let firstReceivedA = receivedAudio.first {
      XCTAssertEqual(firstReceivedA.0, sentAH, "Audio header roundtrip mismatch")
    }

    // Frame payload match (after header)
    let receivedVideoData = receivedVideo.dropFirst().map { $0.0 }
    let receivedAudioData = receivedAudio.dropFirst().map { $0.0 }
    let minVideoMatch = min(receivedVideoData.count, sentVideo.count)
    let minAudioMatch = min(receivedAudioData.count, sentAudio.count)

    for i in 0..<minVideoMatch {
      XCTAssertEqual(receivedVideoData[i], sentVideo[i], "Video frame \(i) payload mismatch")
    }
    for i in 0..<minAudioMatch {
      XCTAssertEqual(receivedAudioData[i], sentAudio[i], "Audio frame \(i) payload mismatch")
    }

    // Timestamps monotonically increasing
    assertMonotonicallyIncreasing(receivedVideo.map { $0.1 }, label: "video")
    assertMonotonicallyIncreasing(receivedAudio.map { $0.1 }, label: "audio")
  }

  // MARK: - Helpers

  private func assertMonotonicallyIncreasing(_ timestamps: [Int64], label: String) {
    for i in 1..<timestamps.count {
      XCTAssertGreaterThanOrEqual(
        timestamps[i], timestamps[i - 1],
        "\(label) timestamp not monotonically increasing at index \(i): \(timestamps[i - 1]) -> \(timestamps[i])"
      )
    }
  }
}

// MARK: - RecordingMP4Delegate

private actor RecordingMP4Delegate: MP4ReaderDelegate {
  private let session: RTMPPublishSession
  private let onStopped: @Sendable () -> Void

  private(set) var sentVideoHeader: Data?
  private(set) var sentAudioHeader: Data?
  private(set) var sentVideoFrames: [Data] = []
  private(set) var sentAudioFrames: [Data] = []

  private var lastVideoTimestamp: UInt64 = 0
  private var lastAudioTimestamp: UInt64 = 0

  init(session: RTMPPublishSession, onStopped: @escaping @Sendable () -> Void) {
    self.session = session
    self.onStopped = onStopped
  }

  func output(reader: MP4Reader, videoHeader: Data) async {
    sentVideoHeader = videoHeader
    await session.publishVideoHeader(data: videoHeader)
  }

  func output(reader: MP4Reader, audioHeader: Data) async {
    sentAudioHeader = audioHeader
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
    sentVideoFrames.append(descData)
    await session.publishVideo(data: descData, delta: delta)
    lastVideoTimestamp = videoFrame.dts
  }

  func output(reader: MP4Reader, audioFrame: AudioFrame) async {
    var audioPacketData = Data()
    audioPacketData.append(audioFrame.adtsHeader)
    audioPacketData.write(AudioData.AACPacketType.raw.rawValue)
    audioPacketData.append(audioFrame.data)

    let delta = UInt32(audioFrame.pts &- lastAudioTimestamp)
    sentAudioFrames.append(audioPacketData)
    await session.publishAudio(data: audioPacketData, delta: delta)
    lastAudioTimestamp = audioFrame.pts
  }

  func output(stopped reader: MP4Reader) async {
    onStopped()
  }
}
