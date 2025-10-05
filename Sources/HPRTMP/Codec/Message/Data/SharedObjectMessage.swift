//
//  SharedObjectMessage.swift
//
//
//  Created by Huiping Guo on 2022/11/03.
//

import Foundation

struct SharedObjectMessage: DataMessage {
  let encodeType: ObjectEncodingType
  let msgStreamId: MessageStreamId

  let sharedObjectName: String?
  let sharedObject: [String: AMFValue]?

  var payload: Data {
    var data = Data()

    let commandNameValue = AMFValue.string("onSharedObject")
    data.append(encodeType == .amf0 ? commandNameValue.amf0Value : commandNameValue.amf3Value)

    if let sharedObjectName {
      let nameValue = AMFValue.string(sharedObjectName)
      data.append(encodeType == .amf0 ? nameValue.amf0Value : nameValue.amf3Value)
    }

    if let sharedObject {
      let objectValue = AMFValue.object(sharedObject)
      data.append(encodeType == .amf0 ? objectValue.amf0Value : objectValue.amf3Value)
    }

    return data
  }
}
