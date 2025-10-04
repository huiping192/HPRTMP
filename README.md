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

- [ ] Connect to RTMP servers and authenticate using various methods
    - [x] RTMP
    - [ ] RTMPS
- [x] Publish and play streams with different media types (audio, video, data)
- [x] Send and receive metadata and event messages
- [x] Handle different message types and chunk sizes for efficient streaming
- [x] Support for multiple streams and different message header types (Type 0, 1, 2, 3)
- [x] Support AMF0 and AMF3 codec


## Requirements

- iOS 14.0+ / macOS 11+
- Swift 6.0+

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
``` 
let session = RTMPPublishSession()
session.delegate = self

// Configure the session
let configure = PublishConfigure()
session.publish(url: "rtmp://your.rtmp.server/app/key", configure: configure)

// Send audio and video headers
session.publishAudioHeader(data: audioHeaderData)
session.publishVideoHeader(data: videoHeaderData, time: 0)

// Publish audio and video data
session.publishAudio(data: audioData, delta: delta)
session.publishVideo(data: videoData, delta: delta)

// Invalidate the session when done
session.invalidate()
```

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or submit a pull request.

# License

HPRTMP is available under the MIT license. See the LICENSE file for more information.
