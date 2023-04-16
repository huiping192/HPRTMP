

public struct PublishConfigure {
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

  public init(width: Int, height: Int, videocodecid: Int, audiocodecid: Int, framerate: Int, videoDatarate: Int?, audioDatarate: Int?, audioSamplerate: Int?) {
    self.width = width
    self.height = height
    self.videocodecid = videocodecid
    self.audiocodecid = audiocodecid
    self.framerate = framerate
    self.videoDatarate = videoDatarate
    self.audioDatarate = audioDatarate
    self.audioSamplerate = audioSamplerate
  }
  
  var meta: [String: Any] {
    var dic: [String: Any] = [
      "width": Int32(width),
      "height": Int32(height),
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate
    ]
    if let videoDatarate {
      dic["videodatarate"] = videoDatarate
    }
    if let audioDatarate {
      dic["audiodatarate"] = audioDatarate
    }
    if let audioSamplerate {
      dic["audiosamplerate"] = audioSamplerate
    }
    return dic
  }
}
