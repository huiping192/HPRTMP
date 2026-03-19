import Foundation
import AVFoundation
import HPRTMP

protocol MP4ReaderDelegate: AnyObject, Sendable {
  func output(reader: MP4Reader, videoHeader: Data) async
  func output(reader: MP4Reader, audioHeader: Data) async
  func output(reader: MP4Reader, videoFrame: VideoFrame) async
  func output(reader: MP4Reader, audioFrame: AudioFrame) async
  func output(stopped reader: MP4Reader) async
}

protocol Frame: Sendable {
  var data: Data { get }
  var ts: UInt64 { get }
}

struct VideoFrame: Frame, Sendable {
  var data: Data
  let isKeyframe: Bool
  let pts: UInt64
  let dts: UInt64

  var ts: UInt64 { dts }
}

struct AudioFrame: Frame, Sendable {
  var data: Data
  let adtsHeader: Data
  let pts: UInt64

  var ts: UInt64 { pts }
}

actor MP4Reader {

  private let url: URL

  private var assetReader: AVAssetReader?
  private var audioReaderOutput: AVAssetReaderTrackOutput?
  private var videoReaderOutput: AVAssetReaderTrackOutput?

  weak var delegate: (any MP4ReaderDelegate)?

  func setDelegate(_ delegate: MP4ReaderDelegate?) {
    self.delegate = delegate
  }

  private var videoTrack: AVAssetTrack?
  private var audioTrack: AVAssetTrack?

  private var videoFrameQueue = PriorityQueue()
  private var audioFrameQueue = PriorityQueue()

  private var frameSendTask: Task<Void, Error>?
  private let frameConverter = FrameConverter()

  private let frameCacheMaxCount = 300

  init(url: URL) {
    self.url = url
  }

  func start() {
    Task {
      await processMP4()
      assetReader?.startReading()

      // precache frames
      for _ in 0..<10 {
        if let videoSampleBuffer = videoReaderOutput?.copyNextSampleBuffer() {
          if let frame = frameConverter.convertVideo(videoSampleBuffer) {
            await videoFrameQueue.enqueue(frame)
          }
        }
        if let audioSampleBuffer = audioReaderOutput?.copyNextSampleBuffer(),
           let frames = frameConverter.convertAudio(audioSampleBuffer, aacHeader: aacHeader!) {
          for frame in frames {
            await audioFrameQueue.enqueue(frame)
          }
        }
      }

      await delegate?.output(reader: self, videoHeader: videoHeader)
      await delegate?.output(reader: self, audioHeader: audioHeader!)

      frameSendTask = Task {
        while !Task.isCancelled && assetReader?.status == .reading {
          asyncReadBuffer()
          await sendNextFrame()
          try? await Task.sleep(nanoseconds: 10 * 1_000_000)
        }
        await delegate?.output(stopped: self)
        await stop()
      }
    }
  }

  func stop() async {
    frameSendTask?.cancel()
    assetReader?.cancelReading()
    await videoFrameQueue.clear()
    await audioFrameQueue.clear()
  }

  func sendNextFrame() async {
    let videoEmpty = await videoFrameQueue.isEmpty
    let audioEmpty = await audioFrameQueue.isEmpty
    guard !videoEmpty && !audioEmpty else { return }

    var frame: Frame?
    let firstVideo = await videoFrameQueue.peek()
    let firstAudio = await audioFrameQueue.peek()

    if let v = firstVideo, let a = firstAudio {
      frame = v.ts < a.ts ? await videoFrameQueue.dequeue() : await audioFrameQueue.dequeue()
    } else if firstVideo != nil {
      frame = await videoFrameQueue.dequeue()
    } else if firstAudio != nil {
      frame = await audioFrameQueue.dequeue()
    }

    if let frame {
      await sendFrame(frame: frame)
    }

    asyncReadBuffer()
  }

  func sendFrame(frame: Frame) async {
    switch frame {
    case let videoFrame as VideoFrame:
      await delegate?.output(reader: self, videoFrame: videoFrame)
    case let audioFrame as AudioFrame:
      await delegate?.output(reader: self, audioFrame: audioFrame)
    default:
      break
    }
  }

  private func asyncReadBuffer() {
    Task {
      if await videoFrameQueue.count < frameCacheMaxCount || frameCacheMaxCount <= 0 {
        await readVideoBuffer()
      }
      if await audioFrameQueue.count < frameCacheMaxCount || frameCacheMaxCount <= 0 {
        await readAudioBuffer()
      }
    }
  }

  private func readVideoBuffer() async {
    if let sample = videoReaderOutput?.copyNextSampleBuffer(),
       let frame = frameConverter.convertVideo(sample) {
      await videoFrameQueue.enqueue(frame)
    }
  }

  private func readAudioBuffer() async {
    if let sample = audioReaderOutput?.copyNextSampleBuffer(),
       let frames = frameConverter.convertAudio(sample, aacHeader: aacHeader!) {
      for frame in frames {
        await audioFrameQueue.enqueue(frame)
      }
    }
  }

  private func processMP4() async {
    let asset = AVURLAsset(url: url)
    guard let assetReader = try? AVAssetReader(asset: asset) else {
      print("Unable to create AVAssetReader")
      return
    }

    let videoTrack: AVAssetTrack?
    let audioTrack: AVAssetTrack?

    if #available(macOS 12.0, iOS 15.0, *) {
      videoTrack = try? await asset.loadTracks(withMediaType: .video).first
      audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
    } else {
      videoTrack = asset.tracks(withMediaType: .video).first
      audioTrack = asset.tracks(withMediaType: .audio).first
    }

    guard let videoTrack, let audioTrack else {
      print("Missing video or audio track")
      return
    }

    let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
    videoReaderOutput.alwaysCopiesSampleData = false
    assetReader.add(videoReaderOutput)

    let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
    audioReaderOutput.alwaysCopiesSampleData = false
    assetReader.add(audioReaderOutput)

    self.assetReader = assetReader
    self.audioReaderOutput = audioReaderOutput
    self.videoReaderOutput = videoReaderOutput
    self.videoTrack = videoTrack
    self.audioTrack = audioTrack
  }

  private var audioHeader: Data? {
    guard let first = audioTrack?.formatDescriptions.first else { return nil }
    let formatDescription = first as! CMFormatDescription

    guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return nil }
    var outFormatDescription: CMFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0,
                                   layout: nil, magicCookieSize: 0, magicCookie: nil,
                                   extensions: nil, formatDescriptionOut: &outFormatDescription)

    guard let streamBasicDesc = outFormatDescription?.streamBasicDesc else { return nil }
    let mp4Id: MPEG4ObjectID = streamBasicDesc.mFormatFlags == 0 ? .AAC_LC :
      (MPEG4ObjectID(rawValue: Int(streamBasicDesc.mFormatFlags)) ?? .AAC_LC)

    var descData = Data()
    let config = AudioSpecificConfig(
      objectType: mp4Id,
      channelConfig: ChannelConfigType(rawValue: UInt8(streamBasicDesc.mChannelsPerFrame)),
      frequencyType: SampleFrequencyType(value: streamBasicDesc.mSampleRate)
    )

    descData.append(aacHeader!)
    descData.write(AudioData.AACPacketType.header.rawValue)
    descData.append(config.encodeData)
    (0..<14).forEach { _ in descData.write(UInt8(0)) }

    return descData
  }

  private var aacHeader: Data? {
    guard let first = audioTrack?.formatDescriptions.first else { return nil }
    let formatDescription = first as! CMFormatDescription

    guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else { return nil }
    var outFormatDescription: CMFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0,
                                   layout: nil, magicCookieSize: 0, magicCookie: nil,
                                   extensions: nil, formatDescriptionOut: &outFormatDescription)

    return buildAACHeader(from: outFormatDescription)
  }

  func buildAACHeader(from outFormatDescription: CMFormatDescription?) -> Data {
    guard let desc = outFormatDescription,
          let streamBasicDesc = desc.streamBasicDesc else {
      return Data()
    }
    let value = (AudioData.SoundFormat.aac.rawValue << 4 |
                 AudioData.SoundRate(value: streamBasicDesc.mSampleRate).rawValue << 2 |
                 AudioData.SoundSize.snd16Bit.rawValue << 1 |
                 AudioData.SoundType.sndStereo.rawValue)
    return Data([UInt8(value)])
  }

  private var videoHeader: Data {
    guard let first = videoTrack?.formatDescriptions.first else { return Data() }
    let formatDescription = first as! CMFormatDescription

    var pointerSPS: UnsafePointer<UInt8>?
    var pointerPPS: UnsafePointer<UInt8>?
    var sizeSPS: size_t = 0
    var sizePPS: size_t = 0
    var lengthSPS: Int32 = 0
    var lengthPPS: Int32 = 0

    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 0,
      parameterSetPointerOut: &pointerSPS, parameterSetSizeOut: &sizeSPS,
      parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthSPS)
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 1,
      parameterSetPointerOut: &pointerPPS, parameterSetSizeOut: &sizePPS,
      parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthPPS)

    let sps = Data(bytes: pointerSPS!, count: sizeSPS)
    let pps = Data(bytes: pointerPPS!, count: sizePPS)

    var body = Data([0x17, 0x00, 0x00, 0x00, 0x00, 0x01])
    body.append(Data([sps[1], sps[2], sps[3], 0xff]))
    body.append(Data([0xe1]))
    body.append(Data([(UInt8(sps.count) >> 8) & 0xff, UInt8(sps.count) & 0xff]))
    body.append(sps)
    body.append(Data([0x01]))
    body.append(Data([(UInt8(pps.count) >> 8) & 0xff, UInt8(pps.count) & 0xff]))
    body.append(pps)

    return body
  }
}
