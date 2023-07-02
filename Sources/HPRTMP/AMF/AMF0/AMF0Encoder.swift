
import Foundation

class AMF0Encoder {
  func encode(_ value: [Any]) -> Data? {
    return value.amf0Value
  }
  
  func encode<T: AMF0Encode>(_ value: T) -> Data? {
    return value.amf0Value
  }
  
  func encode(_ value: [String: Any]) -> Data? {
    return value.amf0Encode
  }
  
  func encodeNil() -> Data? {
    Data([RTMPAMF0Type.null.rawValue])
  }
}
