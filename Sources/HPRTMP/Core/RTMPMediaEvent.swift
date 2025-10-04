//
//  RTMPMediaEvent.swift
//
//
//  Created by Huiping Guo on 2025/10/05.
//

import Foundation

/// 媒体事件类型，通过AsyncStream传递音视频和元数据
public enum RTMPMediaEvent: Sendable {
    /// 音频数据
    /// - Parameters:
    ///   - data: 音频数据
    ///   - timestamp: 时间戳（毫秒）
    case audio(data: Data, timestamp: Int64)

    /// 视频数据
    /// - Parameters:
    ///   - data: 视频数据
    ///   - timestamp: 时间戳（毫秒）
    case video(data: Data, timestamp: Int64)

    /// 元数据
    /// - Parameter metadata: 元数据响应
    case metadata(MetaDataResponse)
}
