//
//  RTMPSocket.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import AVFoundation


public class RTMPSocket {
    
    public convenience init?(url: String) {
        let urlParser = RTMPURLParser()
        guard let urlInfo = try? urlParser.parse(url: url) else { return nil }
        
        self.init(streamURL: urlInfo.url, streamKey: urlInfo.key, port: urlInfo.port)
    }
    
    public init?(streamURL: URL, streamKey: String, port: Int) {
        return nil
    }
    
    
    public func start() {}
    
    
    public func stop() {}
}
