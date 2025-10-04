//
//  RTMPMediaEvent.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/05.
//

import Foundation

/// Media events delivered via AsyncStream
public enum RTMPMediaEvent: Sendable {
    case audio(data: Data, timestamp: Int64)
    case video(data: Data, timestamp: Int64)
    case metadata(MetaDataResponse)
}

/// Stream state events delivered via AsyncStream
public enum RTMPStreamEvent: Sendable {
    case publishStart
    case playStart
    case record
    case pause(Bool)
    case pingRequest(Data)
}

/// Connection events delivered via AsyncStream
public enum RTMPConnectionEvent: Sendable {
    case peerBandwidthChanged(UInt32)
    case statistics(TransmissionStatistics)
    case disconnected
}
