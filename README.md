# HPRTMP

[![CI](https://github.com/huiping192/HPRTMP/actions/workflows/swift.yml/badge.svg?branch=main)](https://github.com/huiping192/HPRTMP/actions/workflows/swift.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)]([https://opensource.org/licenses/MIT](https://github.com/huiping192/LICENSE))
[![Twitter](https://img.shields.io/twitter/follow/huiping192?style=social)](https://twitter.com/huiping192)

## Goals

The main goals of this library are:

- Easy-to-use: Provide a simple and intuitive API for RTMP streaming that abstracts away the complexities of the underlying protocol.
- Efficient: Handle different message types and chunk sizes for efficient streaming.
- Extensible: Allow developers to customize the library and extend its functionality.
- Robust: Handle various network conditions and recover from errors gracefully.

## Features

- [x] Connect to RTMP servers and authenticate using various methods
    - [x] RTMP
    - [x] RTMPS
- [x] **Publishing**: Publish live streams with audio and video
- [x] **Playing**: Play live streams and receive audio/video data
- [x] Send and receive metadata and event messages
- [x] Handle different message types and chunk sizes for efficient streaming
- [x] Support for multiple streams and different message header types (Type 0, 1, 2, 3)
- [x] Support AMF0 and AMF3 codec
- [x] Real-time transmission statistics and monitoring
- [x] Built with Swift 6 strict concurrency support
- [x] Modern async/await API with AsyncStream for event handling


## Architecture

HPRTMP is built with modern Swift technologies:

- **Swift 6 Strict Concurrency**: Full support for Swift 6's strict concurrency checking, ensuring thread-safe operations
- **Actor-based Design**: Core sessions (`RTMPPublishSession`, `RTMPPlayerSession`) are implemented as actors for safe concurrent access
- **AsyncStream Events**: Event-driven architecture using AsyncStream for real-time data flow (video, audio, metadata, statistics)
- **SwiftNIO Network Layer**: High-performance networking built on Apple's SwiftNIO framework with TLS/SSL support

## Requirements

- iOS 14.0+ / macOS 11+
- Swift 6.0+

## Dependencies

- [SwiftNIO](https://github.com/apple/swift-nio) - For high-performance networking
- [SwiftNIO SSL](https://github.com/apple/swift-nio-ssl) - For RTMPS (secure RTMP) support

## Installation

You can install HPRTMP using [Swift Package Manager](https://swift.org/package-manager/) by adding the following line to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/huiping192/HPRTMP.git", from: "0.0.1")
]
```
Alternatively, you can clone this repository and use the included HPRTMP.xcodeproj file, or you can copy the source files directly into your project.


## Usage

### Publishing Example
```swift
let session = RTMPPublishSession()

// Configure the session
let configure = PublishConfigure()

// Start publishing (async operation)
await session.publish(url: "rtmp://your.rtmp.server/app/key", configure: configure)

// Subscribe to status updates
Task {
  for await status in session.statusStream {
    switch status {
    case .publishStart:
      print("Publishing started")
    case .failed(let error):
      print("Failed: \(error)")
    default:
      break
    }
  }
}

// Send audio and video headers
await session.publishAudioHeader(data: audioHeaderData)
await session.publishVideoHeader(data: videoHeaderData)

// Publish audio and video data
await session.publishAudio(data: audioData, delta: delta)
await session.publishVideo(data: videoData, delta: delta)

// Stop publishing when done
await session.stop()
```

### Playing Example
```swift
let session = RTMPPlayerSession()

// Start playing
await session.play(url: "rtmp://your.rtmp.server/app/streamkey")

// Subscribe to video stream
Task {
  for await (videoData, timestamp) in session.videoStream {
    // Handle video data
    print("Received video: \(videoData.count) bytes at \(timestamp)")
  }
}

// Subscribe to audio stream
Task {
  for await (audioData, timestamp) in session.audioStream {
    // Handle audio data
    print("Received audio: \(audioData.count) bytes at \(timestamp)")
  }
}

// Subscribe to metadata
Task {
  for await metadata in session.metaStream {
    print("Received metadata: \(metadata)")
  }
}

// Subscribe to status updates
Task {
  for await status in session.statusStream {
    switch status {
    case .playStart:
      print("Playback started")
    case .failed(let error):
      print("Failed: \(error)")
    case .disconnected:
      print("Disconnected")
    default:
      break
    }
  }
}

// Subscribe to transmission statistics
Task {
  for await stats in session.statisticsStream {
    print("Bitrate: \(stats.currentBitrate) bps")
  }
}

// Stop playing when done
await session.stop()
```

### RTMPS (Secure RTMP) Example
```swift
// Use rtmps:// for secure streaming (default port 443)
await session.publish(url: "rtmps://your.rtmp.server/app/key", configure: configure)

// Or use custom port for publishing
await session.publish(url: "rtmps://your.rtmp.server:8443/app/key", configure: configure)

// Playing also supports RTMPS
await session.play(url: "rtmps://your.rtmp.server/app/streamkey")
```

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or submit a pull request.

# License

HPRTMP is available under the MIT license. See the LICENSE file for more information.
