import Foundation
import HPRTMP

/// Collects video and audio frames from an RTMPPlayerSession.
/// Must be the sole consumer of the session's videoStream / audioStream.
actor MediaCollector {
  private(set) var videoFrames: [(Data, Int64)] = []
  private(set) var audioFrames: [(Data, Int64)] = []

  private var tasks: [Task<Void, Never>] = []

  func startCollecting(from player: RTMPPlayerSession) async {
    let videoStream = await player.videoStream
    let audioStream = await player.audioStream

    let videoTask = Task { [weak self] in
      for await frame in videoStream {
        await self?.append(video: frame)
      }
    }
    let audioTask = Task { [weak self] in
      for await frame in audioStream {
        await self?.append(audio: frame)
      }
    }
    tasks.append(contentsOf: [videoTask, audioTask])
  }

  func stopCollecting() {
    tasks.forEach { $0.cancel() }
    tasks.removeAll()
  }

  private func append(video frame: (Data, Int64)) {
    videoFrames.append(frame)
  }

  private func append(audio frame: (Data, Int64)) {
    audioFrames.append(frame)
  }
}
