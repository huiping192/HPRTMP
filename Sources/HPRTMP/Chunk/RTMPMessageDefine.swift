import Foundation

public enum ObjectEncodingType: UInt8, Decodable {
  case amf0 = 0
  case amf3 = 3
}

enum RTMPVideoFunction: UInt8 {
  case seek = 1
}

enum RTMPAudioCodecsType: UInt16 {
  case none    = 0x0001
  case adpcm   = 0x0002
  case mp3     = 0x0004
  case intel   = 0x0008 //not use
  case unused  = 0x0010 // not use
  case nelly   = 0x0040
  case g711a   = 0x0080
  case g711u   = 0x0100
  case nelly16 = 0x0200
  case aac     = 0x0400
  case speex   = 0x0800
  case all     = 0x0FFF
}

enum RTMPVideoCodecsType: UInt16 {
  case unused    = 0x0001   //Obsolete value
  case jpeg      = 0x0002   //Obsolete value
  case sorenson  = 0x0004   //Sorenson Flash Video
  case homebrew  = 0x0008   // V1 screen sharning
  case vp6       = 0x0010   // on2 video(Flash 8+)
  case vp6Alpha  = 0x0020
  case homebrewv = 0x0040
  case h264      = 0x0080
  case all       = 0x00FF
}

enum MessageType: Equatable {
  
  // controll
  case chunkSize
  case abort
  case acknowledgement
  case control
  case windowAcknowledgement
  case peerBandwidth
  
  
  case command(type: ObjectEncodingType)
  case data(type: ObjectEncodingType)
  case share(type: ObjectEncodingType)
  case audio
  case video
  case aggreate
  case none
  
  init(rawValue: UInt8) {
    switch rawValue {
    case 1:  self = .chunkSize
    case 2:  self = .abort
    case 3:  self = .acknowledgement
    case 4:  self = .control
    case 5:  self = .windowAcknowledgement
    case 6:  self = .peerBandwidth
      
      
    case 20: self = .command(type: .amf0)
    case 17: self = .command(type: .amf3)
    case 18: self = .data(type: .amf0)
    case 15: self = .data(type: .amf3)
    case 19: self = .share(type: .amf0)
    case 16: self = .share(type: .amf3)
    case 8:  self = .audio
    case 9:  self = .video
    case 22: self = .aggreate
    default: self = .none
    }
  }
  
  var rawValue: UInt8 {
    switch self {
    case .chunkSize:
      return 1
    case .abort:
      return 2
    case .acknowledgement:
      return 3
    case .control:
      return 4
    case .windowAcknowledgement:
      return 5
    case .peerBandwidth:
      return 6
    case .command(let type):
      return type == .amf0 ? 20 : 17
    case .data(let type):
      return type == .amf0 ? 18 : 15
    case .share(let type):
      return type == .amf0 ? 19 : 16
    case .audio:
      return 8
    case .video:
      return 9
    case .aggreate:
      return 22
    case .none:
      return 0xff
    }
  }
  
  static func == (lhs: MessageType, rhs: MessageType) -> Bool {
    lhs.rawValue == rhs.rawValue
  }
  
}

public enum VideoData {
  public enum FrameType: Int {
    case keyframe = 1
    case inter = 2
    case disposableInter = 3
    case generated = 4
    case command = 5
  }
  
  public enum CodecId: Int {
    case jpeg = 1
    case h263 = 2
    case screen = 3
    case vp6 = 4
    case vp6Alpha = 5
    case screen2 = 6
    case avc = 7
  }
  
  public enum AVCPacketType: UInt8 {
    case header = 0
    case nalu = 1
    case end = 2
    case none = 0xff
    public init(rawValue: UInt8) {
      switch rawValue {
      case 0: self = .header
      case 1: self = .nalu
      case 2: self = .end
      default: self = .none
      }
    }
  }
}

public enum AudioData {
  public enum SoundFormat: Int {
    case pcmPlatformEndian = 0
    case adpcm = 1
    case mp3 = 2
    case pcmLittleEndian = 3
    case mono16KHZ = 4
    case mono8KHZ = 5
    case nellymoser = 6
    case g711Ａ = 7
    case g711muLaw = 8
    case reserved = 9
    case aac = 10
    case speex = 11
    case mp3_8KHZ = 14
    case device = 15
    
    var headerSize: Int {
      switch self {
      case .aac:
        return 2
      default:
        return 1
      }
    }
  }
  
  public enum SoundRate: Int {
    case kHz5_5 = 0
    case kHz11 = 1
    case kHz22 = 2
    case kHz44 = 3
    
    public init(value: Float64) {
      switch value {
      case 44100:
        self = .kHz44
      case 11025:
        self = .kHz11
      case 22050:
        self = .kHz22
      case 5500:
        self = .kHz5_5
      default:
        self = .kHz44
      }
    }
    
    public var value: Float64 {
      switch self {
      case .kHz5_5:
        return 5500
      case .kHz11:
        return 11025
      case .kHz22:
        return 22050
      case .kHz44:
        return 44100
      }
    }
  }
  
  public enum SoundSize: Int {
    case snd8Bit = 0
    case snd16Bit = 1
  }
  
  public enum SoundType: Int {
    case sndMono = 0
    case sndStereo = 1
  }
  
  public enum AACPacketType: UInt8 {
    case header = 0
    case raw = 1
  }
}

public enum ChannelConfigType: UInt8 {
  // C = Center
  // L = Left
  // R = Right
  // LFE = LFE-channel
  case aot = 0
  case front_C = 1
  case front_LR = 2
  case front_CLR = 3
  case front_CLR_back_C = 4
  case front_CLR_back_LR = 5
  case front_CLR_back_LR_LFE = 6
  case front_CLR_side_LR_back_LR_LFE = 7
  case reserved = 8
  case unknown = 0xff
  public init(rawValue: UInt8) {
    switch rawValue {
    case 0: self = .aot
    case 1: self = .front_C
    case 2: self = .front_LR
    case 3: self = .front_CLR
    case 4: self = .front_CLR_back_C
    case 5: self = .front_CLR_back_LR
    case 6: self = .front_CLR_back_LR_LFE
    case 7: self = .front_CLR_side_LR_back_LR_LFE
    case 8: self = .reserved
    default: self = .unknown
    }
  }
}

public enum SampleFrequencyType: UInt8 {
  case kHz96000 = 0
  case kHz88200 = 1
  case kHz64000 = 2
  case kHz48000 = 3
  case kHz44100 = 4
  case kHz32000 = 5
  case kHz24000 = 6
  case kHz22050 = 7
  case kHz16000 = 8
  case kHz12000 = 9
  case kHz11025 = 10
  case kHz8000 = 11
  case kHz7350 = 12
  case reserved0 = 13
  case reserved1 = 14
  case writenExplictly = 15
  case unknown = 0xff
  public init(rawValue: UInt8) {
    switch rawValue {
    case 0: self = .kHz96000
    case 1: self = .kHz88200
    case 2: self = .kHz64000
    case 3: self = .kHz48000
    case 4: self = .kHz44100
    case 5: self = .kHz32000
    case 6: self = .kHz24000
    case 7: self = .kHz22050
    case 8: self = .kHz16000
    case 9: self = .kHz12000
    case 10: self = .kHz11025
    case 11: self = .kHz8000
    case 12: self = .kHz7350
    case 13: self = .reserved0
    case 14: self = .reserved1
    case 15: self = .writenExplictly
    default: self = .unknown
    }
  }
  
  public init(value: Double) {
    switch value {
    case 96000: self = .kHz96000
    case 88200: self = .kHz88200
    case 64000: self = .kHz64000
    case 48000: self = .kHz48000
    case 44100: self = .kHz44100
    case 32000: self = .kHz32000
    case 24000: self = .kHz24000
    case 22050: self = .kHz22050
    case 16000: self = .kHz16000
    case 12000: self = .kHz12000
    case 11025: self = .kHz11025
    case 8000: self = .kHz8000
    case 7350: self = .kHz7350
    default: self = .unknown
    }
    
    
  }
  public var value: Int {
    switch self {
    case .kHz96000: return 96000
    case .kHz88200: return 88200
    case .kHz64000: return 64000
    case .kHz48000: return 48000
    case .kHz44100: return 44100
    case .kHz32000: return 32000
    case .kHz24000: return 24000
    case .kHz22050: return 22050
    case .kHz16000: return 16000
    case .kHz12000: return 12000
    case .kHz11025: return 11025
    case .kHz8000: return 8000
    case .kHz7350: return 7350
    case .unknown, .reserved0, .reserved1 , .writenExplictly: return 0xff
    }
  }
}
