//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/25.
//

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
