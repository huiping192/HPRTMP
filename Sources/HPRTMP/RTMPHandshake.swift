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
    
    static let PacketSize = 1536
    static let rtmpVersion: UInt8 = 3
    var timestamp:TimeInterval = 0
    var data = Data() {
        didSet {
            if checkTimer == nil && data.count > 0 {
                checkTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(statusCheck), userInfo: nil, repeats: true)
            }
        }
    }
    
    var checkTimer: Timer?
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
        let randomSize = RTMPHandshake.PacketSize - data.count
        (0...randomSize).forEach { _ in
            data.write(UInt8(arc4random_uniform(0xff)))
        }
        return data
    }

    var c2Packet: Data {
        var data = Data()
        // s1 timestamp
        data.append(self.data.subdata(in: 1..<5))
        // timestamp
        data.write(UInt32(Date().timeIntervalSince1970 - timestamp).toUInt8Array())
        // c2 random
        data.append(self.data.subdata(in: 9..<RTMPHandshake.PacketSize+1))
        return data
    }

   
    func startHandShake() {
        self.status = .uninitalized
    }
    
    func reset() {
        checkTimer?.invalidate()
        checkTimer = nil
        data.removeAll()
        self.status = .none
    }
    
    @objc func statusCheck() {
        switch self.status {
        case .uninitalized:
            if self.data.count < RTMPHandshake.PacketSize+1  {
                break
            }
            self.status = .verSent
            self.data.removeSubrange(0...RTMPHandshake.PacketSize)
        case .verSent:
            if self.data.count < RTMPHandshake.PacketSize {
                return
            }
            self.status = .ackSent
        case .ackSent:
            if self.data.isEmpty {
                return
            }
            self.status = .handshakeDone
            self.data.removeAll()
            checkTimer?.invalidate()
            checkTimer = nil
        default:
            break
        }
    }
}


