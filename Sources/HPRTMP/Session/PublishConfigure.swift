

public struct PublishConfigure: Sendable {
  let width: Int
  let height: Int
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  // kpbss
  let videoDatarate: Int?
  // kpbss
  let audioDatarate: Int?
  let audioSamplerate: Int?

  public init(width: Int, height: Int, videocodecid: Int, audiocodecid: Int, framerate: Int, videoDatarate: Int? = nil, audioDatarate: Int? = nil, audioSamplerate: Int? = nil) {
    self.width = width
    self.height = height
    self.videocodecid = videocodecid
    self.audiocodecid = audiocodecid
    self.framerate = framerate
    self.videoDatarate = videoDatarate
    self.audioDatarate = audioDatarate
    self.audioSamplerate = audioSamplerate
  }
  
  var metaData: MetaData {
    MetaData(
      width: Int32(width),
      height: Int32(height),
      videocodecid: videocodecid,
      audiocodecid: audiocodecid,
      framerate: framerate,
      videodatarate: videoDatarate,
      audiodatarate: audioDatarate,
      audiosamplerate: audioSamplerate
    )
  }
}
