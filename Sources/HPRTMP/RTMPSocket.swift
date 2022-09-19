//
//  RTMPSocket.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation
import AVFoundation


public enum RTMPState {
    case none
    case open
    case connected
    case closed
}


public protocol RTMPSocketDelegate: AnyObject {
    
}


public class RTMPSocket: NSObject {
    
    private static let maxReadSize = Int(UInt16.max)
    
    private let inputQueue = DispatchQueue(label: "HPRTMP.inputQueue")
    private let outputQueue = DispatchQueue(label: "HPRTMP.outputQueue")
    private var input: InputStream?
    private var output: OutputStream?
    private var runloop: RunLoop?
    
    private var buffer:UnsafeMutablePointer<UInt8>?
    private var inputData = Data()
    
    private var state: RTMPState = .none
    
    weak var delegate: RTMPSocketDelegate?
    
    private let urlInfo: RTMPURLInfo
    
    public init?(url: String) {
        let urlParser = RTMPURLParser()
        guard let urlInfo = try? urlParser.parse(url: url) else { return nil }
        self.urlInfo = urlInfo
    }
    
    public init?(streamURL: URL, streamKey: String, port: Int) {
        let urlInfo = RTMPURLInfo(url: streamURL, key: streamKey, port: port)
        self.urlInfo = urlInfo
    }
    
    
    
}

// public func
extension RTMPSocket {
    public func resume() {
        guard state != .connected else { return }
        inputQueue.async { [unowned self] in
            Stream.getStreamsToHost(withName: self.urlInfo.host,
                                    port: self.urlInfo.port,
                                    inputStream: &self.input,
                                    outputStream: &self.output)
            self.setParameter()
        }
    }
    
    public func stop() {
        guard state != .closed && state != .none else { return }
        self.clearParameter()
//        handshake.reset()
//        decoder.reset()
//        encoder.reset()
//        info.reset(clearInfo)
    }
    
    
}

// socket handling
extension RTMPSocket {
    func setParameter() {
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: RTMPSocket.maxReadSize)
        buffer?.initialize(repeating: 0, count: RTMPSocket.maxReadSize)
        if let delegate = self as? StreamDelegate {
            self.input?.delegate = delegate
            self.output?.delegate = delegate
        }
        self.runloop = .current
        self.input?.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
        self.input?.schedule(in: self.runloop!, forMode: RunLoop.Mode.default)
        self.input?.setProperty(StreamSocketSecurityLevel.none, forKey: .socketSecurityLevelKey)
        self.output?.schedule(in: self.runloop!, forMode: RunLoop.Mode.default)
        self.output?.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
        self.input?.open()
        self.output?.open()
        self.runloop?.run()
    }
    
    open func clearParameter() {
        self.input?.close()
        self.input?.remove(from: runloop!, forMode: RunLoop.Mode.default)
        self.input?.delegate = nil
        self.output?.close()
        self.output?.remove(from: runloop!, forMode: RunLoop.Mode.default)
        self.output?.delegate = nil
        self.input = nil
        self.output = nil
        buffer?.deinitialize(count: RTMPSocket.maxReadSize)
        buffer?.deallocate()
        buffer = nil
        inputData.removeAll()
        
        guard let r = self.runloop else {
            return
        }
        CFRunLoopStop(r.getCFRunLoop())
        self.runloop = nil
    }
}
