import Foundation

struct ConnectResponse {
  var description: String
  var level: String
  var code: CodeType.Connect
  
  init?(info: [String: Any?]?) {
    guard let code = info?["code"] as? String else { return nil }
    self.code = CodeType.Connect(rawValue: code) ?? .failed
    
    guard let level = info?["level"] as? String else { return nil }
    self.level = level
    guard let description = info?["description"] as? String else { return nil }
    self.description = description
  }
}
