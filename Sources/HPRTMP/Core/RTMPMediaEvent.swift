//
//  RTMPMediaEvent.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/05.
//

import Foundation

/// Media events delivered via AsyncStream
///
/// These events are emitted when the RTMP connection receives audio/video data
/// from the server. Consumers can subscribe to these events through the
/// `mediaEvents` AsyncStream on `RTMPConnection`.
///
/// ## Example
/// ```swift
/// for await event in connection.mediaEvents {
///     switch event {
///     case .audio(let data, let timestamp):
///         // Process audio data
///     case .video(let data, let timestamp):
///         // Process video data
///     case .metadata(let response):
///         // Process metadata
///     }
/// }
/// ```
public enum RTMPMediaEvent: Sendable {
    /// Audio data received from the server
    /// - Parameters:
    ///   - data: Raw audio data (AAC, MP3, etc.)
    ///   - timestamp: Presentation timestamp in milliseconds (Int64 for flexibility)
    case audio(data: Data, timestamp: Int64)

    /// Video data received from the server
    /// - Parameters:
    ///   - data: Raw video data (H.264, H.265, etc.)
    ///   - timestamp: Presentation timestamp in milliseconds (Int64 for flexibility)
    case video(data: Data, timestamp: Int64)

    /// Metadata response (onMetaData) containing stream information
    case metadata(MetaDataResponse)
}

/// Stream state events delivered via AsyncStream
///
/// These events indicate changes in the RTMP stream state, such as
/// publish/play start, recording status, and ping requests.
public enum RTMPStreamEvent: Sendable {
    /// Server has accepted the publish request
    case publishStart

    /// Server has started playing the stream
    case playStart

    /// Server has started recording the stream
    case record

    /// Stream has been paused or unpaused
    /// - Parameter isPaused: true if paused, false if resumed
    case pause(Bool)

    /// Server sent a ping request requiring response
    /// - Parameter data: Ping request data that should be echoed back
    case pingRequest(Data)
}

/// Connection events delivered via AsyncStream
///
/// These events provide information about the connection state,
/// including bandwidth changes, transmission statistics, and disconnection.
public enum RTMPConnectionEvent: Sendable {
    /// Server's peer bandwidth limit has changed
    /// - Parameter size: New bandwidth limit in bytes per second
    case peerBandwidthChanged(UInt32)

    /// Periodic transmission statistics update
    case statistics(TransmissionStatistics)

    /// Connection has been disconnected
    case disconnected
}
