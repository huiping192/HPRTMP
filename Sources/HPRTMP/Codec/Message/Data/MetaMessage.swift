//
//  MetaMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

public struct MetaData: Sendable {
  let width: Int32
  let height: Int32
  let videocodecid: Int
  let audiocodecid: Int
  let framerate: Int
  let videodatarate: Int?
  let audiodatarate: Int?
  let audiosamplerate: Int?

  var dictionary: [String: Any] {
    var dic: [String: Any] = [
      "width": width,
      "height": height,
      "videocodecid": videocodecid,
      "audiocodecid": audiocodecid,
      "framerate": framerate
    ]
    if let videodatarate {
      dic["videodatarate"] = videodatarate
    }
    if let audiodatarate {
      dic["audiodatarate"] = audiodatarate
    }
    if let audiosamplerate {
      dic["audiosamplerate"] = audiosamplerate
    }
    return dic
  }
}

struct MetaMessage: DataMessage {
  let encodeType: ObjectEncodingType
  let msgStreamId: MessageStreamId
  let meta: MetaData

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string("onMetaData")

    // Convert meta.dictionary to [String: AMFValue]
    var metaDict: [String: AMFValue] = [
      "width": .double(Double(meta.width)),
      "height": .double(Double(meta.height)),
      "videocodecid": .double(Double(meta.videocodecid)),
      "audiocodecid": .double(Double(meta.audiocodecid)),
      "framerate": .double(Double(meta.framerate))
    ]
    if let videodatarate = meta.videodatarate {
      metaDict["videodatarate"] = .double(Double(videodatarate))
    }
    if let audiodatarate = meta.audiodatarate {
      metaDict["audiodatarate"] = .double(Double(audiodatarate))
    }
    if let audiosamplerate = meta.audiosamplerate {
      metaDict["audiosamplerate"] = .double(Double(audiosamplerate))
    }

    let metaValue = AMFValue.object(metaDict)

    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)
    data.append(encodeType == .amf0 ? metaValue.amf0Value : metaValue.amf3Value)

    return data
  }
}
