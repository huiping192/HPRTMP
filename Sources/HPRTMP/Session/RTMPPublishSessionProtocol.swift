import Foundation

/// Protocol defining the public interface for RTMP publishing sessions
public protocol RTMPPublishSessionProtocol: Actor {
  /// Current publishing status
  var publishStatus: RTMPPublishStatus { get }

  /// Stream of status updates
  var statusStream: AsyncStream<RTMPPublishStatus> { get }

  /// Stream of transmission statistics
  var statisticsStream: AsyncStream<TransmissionStatistics> { get }

  /// Start publishing to the specified RTMP URL
  /// - Parameters:
  ///   - url: The RTMP server URL
  ///   - configure: Publishing configuration including metadata
  func publish(url: String, configure: PublishConfigure) async

  /// Publish video header data (sequence header)
  /// - Parameter data: Video header data (e.g., SPS/PPS for H.264)
  func publishVideoHeader(data: Data) async

  /// Publish video frame data
  /// - Parameters:
  ///   - data: Video frame data
  ///   - delta: Timestamp delta in milliseconds
  func publishVideo(data: Data, delta: UInt32) async

  /// Publish audio header data (sequence header)
  /// - Parameter data: Audio header data (e.g., AAC config)
  func publishAudioHeader(data: Data) async

  /// Publish audio frame data
  /// - Parameters:
  ///   - data: Audio frame data
  ///   - delta: Timestamp delta in milliseconds
  func publishAudio(data: Data, delta: UInt32) async

  /// Stop publishing and disconnect from the server
  func stop() async
}
