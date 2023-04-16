import Foundation

struct ConnectResponse {
  var description: String
  var level: String
  var code: CodeType.Connect
  
  var objectEncoding: ObjectEncodingType
  
  init?(info: Any?) {
    guard let info = info as? [String: Any?] else { return nil }
    guard let code = info["code"] as? String else { return nil }
    self.code = CodeType.Connect(rawValue: code) ?? .failed
    
    guard let level = info["level"] as? String else { return nil }
    self.level = level
    guard let description = info["description"] as? String else { return nil }
    self.description = description
    
    guard let objectEncoding = info["objectEncoding"] as? Double else { return nil }
    self.objectEncoding = ObjectEncodingType(rawValue: UInt8(objectEncoding)) ?? .amf0
  }
}

struct StatusResponse: Decodable {
  enum Level: String, Decodable {
    case warning = "warning"
    case status = "status"
    case error = "error"
  }
  
  enum StreamStatus: String, Decodable {
    case bufferEmpty               = "NetStream.Buffer.Empty"
    case bufferFlush               = "NetStream.Buffer.Flush"
    case bufferFull                = "NetStream.Buffer.Full"
    
    case connectClosed             = "NetStream.Connect.Closed"
    case connectFailed             = "NetStream.Connect.Failed"
    case connectRejected           = "NetStream.Connect.Rejected"
    case connectSuccess            = "NetStream.Connect.Success"
    
    case drmUpdateNeeded           = "NetStream.DRM.UpdateNeeded"
    case failed                    = "NetStream.Failed"
    case multicastStreamReset      = "NetStream.MulticastStream.Reset"
    
    case pauseNotify               = "NetStream.Pause.Notify"
    
    case playFailed                = "NetStream.Play.Failed"
    case playFileStructureInvalid  = "NetStream.Play.FileStructureInvalid"
    case playInsufficientBW        = "NetStream.Play.InsufficientBW"
    case playNoSupportedTrackFound = "NetStream.Play.NoSupportedTrackFound"
    case playReset                 = "NetStream.Play.Reset"
    case playStart                 = "NetStream.Play.Start"
    case playStop                  = "NetStream.Play.Stop"
    case playStreamNotFound        = "NetStream.Play.StreamNotFound"
    case playTransition            = "NetStream.Play.Transition"
    case playUnpublishNotify       = "NetStream.Play.UnpublishNotify"
    
    case publishBadName            = "NetStream.Publish.BadName"
    case publishIdle               = "NetStream.Publish.Idle"
    case publishStart              = "NetStream.Publish.Start"
    case recordAlreadyExists       = "NetStream.Record.AlreadyExists"
    case recordFailed              = "NetStream.Record.Failed"
    case recordNoAccess            = "NetStream.Record.NoAccess"
    case recordStart               = "NetStream.Record.Start"
    case recordStop                = "NetStream.Record.Stop"
    case recordDiskQuotaExceeded   = "NetStream.Record.DiskQuotaExceeded"
    case secondScreenStart         = "NetStream.SecondScreen.Start"
    case secondScreenStop          = "NetStream.SecondScreen.Stop"
    case seekFailed                = "NetStream.Seek.Failed"
    case seekInvalidTime           = "NetStream.Seek.InvalidTime"
    case seekNotify                = "NetStream.Seek.Notify"
    case stepNotify                = "NetStream.Step.Notify"
    case unpauseNotify             = "NetStream.Unpause.Notify"
    case unpublishSuccess          = "NetStream.Unpublish.Success"
    case videoDimensionChange      = "NetStream.Video.DimensionChange"
  }
  let code: StreamStatus?
  let level: Level?
  let description: String?
  
  init?(info: Any?) {
    guard let info = info as? [String: Any?] else { return nil }
    guard let code = info["code"] as? String else { return nil }
    self.code = StreamStatus(rawValue: code) ?? .failed
    
    guard let level = info["level"] as? String else { return nil }
    self.level = Level(rawValue: level)
    self.description = info["description"] as? String
  }
  
}

public struct SampleDescription {
  public let sampletype: String
}

public struct Trackinfo {
  public let sampledescription : [SampleDescription]
  public let language : String
  public let timescale : Double
  public let length : Double
}

public struct MetaDataResponse {
  public var duration : Double = 0
  public var height : Int = 0
  public var frameWidth : Int = 0
  public var moovposition : Int = 0
  public var framerate : Int = 0
  public var avcprofile : Int = 0
  public var videocodecid : String = ""
  public var frameHeight : Int = 0
  public var videoframerate : Int = 0
  public var audiochannels : Int = 0
  public var displayWidth : Int = 0
  public var displayHeight : Int = 0
  public var trackinfo = [Trackinfo]()
  public var width : Int = 0
  public var avclevel : Int = 0
  public var audiosamplerate : Int = 0
  public var aacaot : Int = 0
  public var audiocodecid : String = ""
  
  enum CodingKeys: String, CodingKey {
    case duration = "duration"
    case height = "height"
    case frameWidth = "frameWidth"
    case moovposition = "moovposition"
    case framerate = "framerate"
    case avcprofile = "avcprofile"
    case videocodecid = "videocodecid"
    case frameHeight = "frameHeight"
    case videoframerate = "videoframerate"
    case audiochannels = "audiochannels"
    case displayWidth = "displayWidth"
    case displayHeight = "displayHeight"
    case trackinfo = "trackinfo"
    case width = "width"
    case avclevel = "avclevel"
    case audiosamplerate = "audiosamplerate"
    case aacaot = "aacaot"
    case audiocodecid = "audiocodecid"
  }
  
  init?(commandObject: [String: Any?]?) {
    guard let commandObject = commandObject else { return nil }
    
    if let duration = commandObject["duration"] as? Double {
      self.duration = duration
    }
    if let height = commandObject["height"] as? Int {
      self.height = height
    }
    if let frameWidth = commandObject["frameWidth"] as? Int {
      self.frameWidth = frameWidth
    }
    if let moovposition = commandObject["moovposition"] as? Int {
      self.moovposition = moovposition
    }
    if let framerate = commandObject["framerate"] as? Int {
      self.framerate = framerate
    }
    if let avcprofile = commandObject["avcprofile"] as? Int {
      self.avcprofile = avcprofile
    }
    if let videocodecid = commandObject["videocodecid"] as? String {
      self.videocodecid = videocodecid
    }
    if let frameHeight = commandObject["frameHeight"] as? Int {
      self.frameHeight = frameHeight
    }
    if let videoframerate = commandObject["videoframerate"] as? Int {
      self.videoframerate = videoframerate
    }
    if let audiochannels = commandObject["audiochannels"] as? Int {
      self.audiochannels = audiochannels
    }
    if let displayWidth = commandObject["displayWidth"] as? Int {
      self.displayWidth = displayWidth
    }
    if let displayHeight = commandObject["displayHeight"] as? Int {
      self.displayHeight = displayHeight
    }
    if let width = commandObject["width"] as? Int {
      self.width = width
    }
    if let avclevel = commandObject["avclevel"] as? Int {
      self.avclevel = avclevel
    }
    if let audiosamplerate = commandObject["audiosamplerate"] as? Int {
      self.audiosamplerate = audiosamplerate
    }
    if let aacaot = commandObject["aacaot"] as? Int {
      self.aacaot = aacaot
    }
    if let audiocodecid = commandObject["audiocodecid"] as? String {
      self.audiocodecid = audiocodecid
    }
    if let trackinfoArray = commandObject["trackinfo"] as? [[String: Any?]] {
      var trackinfo = [Trackinfo]()
      for trackinfoDict in trackinfoArray {
        if let timescale = trackinfoDict["timescale"] as? Double,
           let length = trackinfoDict["length"] as? Double,
           let language = trackinfoDict["language"] as? String,
           let sampledescriptionArray = trackinfoDict["sampledescription"] as? [[String: Any?]] {
          var sampledescription = [SampleDescription]()
          for sampledescriptionDict in sampledescriptionArray {
            if let sampletype = sampledescriptionDict["sampletype"] as? String {
              sampledescription.append(SampleDescription(sampletype: sampletype))
            }
          }
          trackinfo.append(Trackinfo(sampledescription: sampledescription, language: language, timescale: timescale, length: length))
        }
      }
      self.trackinfo = trackinfo
    }
  }
}
