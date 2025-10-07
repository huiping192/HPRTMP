import Foundation
struct RTMPURLInfo {
  let url: URL
  let scheme: String
  let isSecure: Bool
  var tcUrl: String {
    "\(scheme)://\(host)/\(appName)"
  }
  let appName: String
  let key: String
  let port: Int

  var host: String {
    return url.host!
  }
}

enum RTMPURLParsingError: Error {
  case invalidScheme
  case invalidURL
  case missingAppNameOrKey
}

struct RTMPURLParser {
  init() {}
  
  func parse(url: String) throws -> RTMPURLInfo? {
    guard let parsedURL = URL(string: url) else {
      throw RTMPURLParsingError.invalidURL
    }

    guard let scheme = parsedURL.scheme, (scheme == "rtmp" || scheme == "rtmps") else {
      throw RTMPURLParsingError.invalidScheme
    }

    let pathComponents = parsedURL.pathComponents
    guard pathComponents.count >= 3 else {
      throw RTMPURLParsingError.missingAppNameOrKey
    }

    let appName = pathComponents[1]
    let key = pathComponents[2]
    let isSecure = scheme == "rtmps"
    let defaultPort = isSecure ? 443 : 1935
    let port = parsedURL.port ?? defaultPort

    return RTMPURLInfo(url: parsedURL, scheme: scheme, isSecure: isSecure, appName: appName, key: key, port: port)
  }
}
