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

class RTMPURLParser {
    init() {}
    
    func parse(url: String) throws -> RTMPURLInfo? {
        
        return nil
    }
}
