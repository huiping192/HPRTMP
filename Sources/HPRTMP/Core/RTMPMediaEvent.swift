//
//  RTMPMediaEvent.swift
//  HPRTMP
//
//  Created by Huiping Guo on 2025/10/05.
//

import Foundation

/// Media events delivered via AsyncStream
///
/// These events are emitted when audio/video data or metadata is received from the RTMP stream.
/// Consumers subscribe to `RTMPConnection.mediaEvents` to receive these events.
///
/// Example:
/// ```swift
/// Task {
///   for await event in connection.mediaEvents {
///     switch event {
///     case .audio(let data, let timestamp):
///       // Process audio data
///     case .video(let data, let timestamp):
///       // Process video data
///     case .metadata(let meta):
///       // Process metadata
///     }
///   }
/// }
/// ```
public enum RTMPMediaEvent: Sendable {
    /// Audio data received from the stream
    /// - Parameters:
    ///   - data: Raw audio data (including FLV audio header)
    ///   - timestamp: Presentation timestamp in milliseconds
    case audio(data: Data, timestamp: Int64)
    
    /// Video data received from the stream
    /// - Parameters:
    ///   - data: Raw video data (including FLV video header)
    ///   - timestamp: Presentation timestamp in milliseconds
    case video(data: Data, timestamp: Int64)
    
    /// Metadata (onMetaData) received from the stream
    /// Contains stream metadata like duration, dimensions, codec info, etc.
    case metadata(MetaDataResponse)
}

/// Stream state events delivered via AsyncStream
///
/// These events indicate changes in stream state such as publishing started,
/// playback started, pause state changes, etc.
///
/// Consumers subscribe to `RTMPConnection.streamEvents` to receive these events.
public enum RTMPStreamEvent: Sendable {
    /// Publish operation has started (sent by server)
    case publishStart
    
    /// Playback has started (sent by server)
    case playStart
    
    /// Stream is being recorded (sent by server)
    case record
    
    /// Stream pause state changed
    /// - Parameter isPaused: true if stream is paused, false if resumed
    case pause(Bool)
    
    /// Ping request from server (RTMP ping mechanism)
    /// The client should respond with a ping response.
    /// - Parameter data: Ping timestamp data from server
    case pingRequest(Data)
}

/// Connection events delivered via AsyncStream
///
/// These events indicate changes in connection state such as bandwidth changes,
/// statistics updates, disconnection, etc.
///
/// Consumers subscribe to `RTMPConnection.connectionEvents` to receive these events.
public enum RTMPConnectionEvent: Sendable {
    /// Peer bandwidth (upload/download limit) has changed
    /// - Parameter size: New bandwidth limit in bytes
    case peerBandwidthChanged(UInt32)
    
    /// Periodic transmission statistics update
    case statistics(TransmissionStatistics)
    
    /// Connection has been disconnected
    case disconnected
}
