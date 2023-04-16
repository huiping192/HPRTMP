

public struct PublishConfigure {
  let width: Int
  let height: Int
  let displayWidth: Int
  let displayHeight: Int
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  let videoframerate: Int
  
  public init(width: Int, height: Int, displayWidth: Int, displayHeight: Int, videocodecid: Int, audiocodecid: Int, framerate: Int, videoframerate: Int) {
    self.width = width
    self.height = height
    self.displayWidth = displayWidth
    self.displayHeight = displayHeight
    self.videocodecid = videocodecid
    self.audiocodecid = audiocodecid
    self.framerate = framerate
    self.videoframerate = videoframerate
  }
  
  var meta: [String: Any] {
    return [
      "width": Int32(width),
      "height": Int32(height),
      "displayWidth": Int32(displayWidth),
      "displayHeight": Int32(displayHeight),
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate,
      "videoframerate": videoframerate
    ]
  }
}
