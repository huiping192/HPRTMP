//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/09/19.
//

import Foundation

class RTMPHandshake {
    enum Status {
        case uninitalized
        case verSent
        case ackSent
        case handshakeDone
        case none
    }
    
    // const 1536 byte
    static let packetSize = 1536
    static let rtmpVersion: UInt8 = 3
    var timestamp:TimeInterval = 0
    var serverData = Data() {
        didSet {
            if checkTimer == nil && serverData.count > 0 {
                checkTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(statusCheck), userInfo: nil, repeats: true)
            }
        }
    }
    
    private var checkTimer: Timer?
    public var changeBlock:((_ status:Status)->Void)?
    public init(statusChange: ((_ status:Status)->Void)?) {
        self.changeBlock = statusChange
    }
    
    private(set) var status = Status.none {
        didSet {
            switch status {
            case .none, .uninitalized:
                timestamp = 0
            case .verSent:
                break
            default:
                break
            }
            self.changeBlock?(status)
        }
    }
    
    var c0c1Packet: Data {
        var data = Data()
        
        // rtmp version
        data.write(RTMPHandshake.rtmpVersion)
        // time stamp
        data.write(UInt32(timestamp).toUInt8Array())
        // const 0,0,0,0
        data.write([0x00,0x00,0x00,0x00])
        
        // random
        let randomSize = RTMPHandshake.packetSize - data.count
        (0...randomSize).forEach { _ in
            data.write(UInt8(arc4random_uniform(0xff)))
        }
        return data
    }

    var c2Packet: Data {
        var data = Data()
        // s1 timestamp
        data.append(self.serverData.subdata(in: 1..<5))
        // timestamp
        data.write(UInt32(Date().timeIntervalSince1970 - timestamp).toUInt8Array())
        // c2 random
        data.append(self.serverData.subdata(in: 9..<RTMPHandshake.packetSize+1))
        return data
    }

   
    func startHandShake() {
        self.status = .uninitalized
    }
    
    func reset() {
        checkTimer?.invalidate()
        checkTimer = nil
        serverData.removeAll()
        self.status = .none
    }
    
    @objc func statusCheck() {
        switch self.status {
        case .uninitalized:
            if self.serverData.count < RTMPHandshake.packetSize+1  {
                break
            }
            self.status = .verSent
            self.serverData.removeSubrange(0...RTMPHandshake.packetSize)
        case .verSent:
            if self.serverData.count < RTMPHandshake.packetSize {
                return
            }
            self.status = .ackSent
        case .ackSent:
            if self.serverData.isEmpty {
                return
            }
            self.status = .handshakeDone
            self.serverData.removeAll()
            checkTimer?.invalidate()
            checkTimer = nil
        default:
            break
        }
    }
}


