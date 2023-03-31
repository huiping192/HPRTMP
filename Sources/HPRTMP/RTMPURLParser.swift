//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation

struct RTMPURLInfo {
  let url: URL
  let key: String
  let port: Int
  
  var host: String {
    return url.host!
  }
}

enum RTMPURLParsingError: Error {
    case invalidScheme
    case invalidURL
}

struct RTMPURLParser {
  init() {}
  
  func parse(url: String) throws -> RTMPURLInfo? {
    guard let parsedURL = URL(string: url) else {
      return nil
    }
    
    guard let scheme = parsedURL.scheme, scheme == "rtmp" else {
      throw RTMPURLParsingError.invalidScheme
    }
    
    let port = parsedURL.port ?? 1935
    let key = parsedURL.path.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
    
    return RTMPURLInfo(url: parsedURL, key: key, port: port)
  }
}
