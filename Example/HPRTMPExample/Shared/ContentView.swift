//
//  ContentView.swift
//  Shared
//
//  Created by Huiping Guo on 2022/10/22.
//

import SwiftUI
import HPRTMP

struct ContentView: View {
  @StateObject private var rtmpService = RTMPService()
  @AppStorage("rtmpURL") private var rtmpURL: String = "rtmp://192.168.11.23:1936/live/stream"

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        serverSection
        statusSection
        controlSection
        if rtmpService.isRunning, let stats = rtmpService.statistics {
          StatisticsView(statistics: stats)
        }
      }
      .padding()
    }
  }

  // MARK: - Server Section

  private var serverSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Server")
        .font(.headline)
      TextField("rtmp://host:port/app/stream", text: $rtmpURL)
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
        .keyboardType(.URL)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        #endif
    }
  }

  // MARK: - Status Section

  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Status")
        .font(.headline)
      HStack(spacing: 10) {
        Circle()
          .fill(statusColor)
          .frame(width: 12, height: 12)
        Text(statusText)
          .foregroundColor(statusColor)
      }
      if let error = rtmpService.errorMessage {
        Text(error)
          .foregroundColor(.red)
          .font(.caption)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(10)
  }

  private var statusColor: Color {
    switch rtmpService.connectionStatus {
    case .unknown: return .gray
    case .handShakeStart, .handShakeDone: return .orange
    case .connect: return .yellow
    case .publishStart: return .green
    case .failed: return .red
    case .disconnected: return .gray
    default: return .gray
    }
  }

  private var statusText: String {
    switch rtmpService.connectionStatus {
    case .unknown: return "Idle"
    case .handShakeStart: return "Handshaking..."
    case .handShakeDone: return "Handshake Done"
    case .connect: return "Connecting..."
    case .publishStart: return "Publishing"
    case .failed: return "Failed"
    case .disconnected: return "Disconnected"
    default: return "Unknown"
    }
  }

  // MARK: - Control Section

  private var controlSection: some View {
    Button(action: {
      Task {
        if rtmpService.isRunning {
          await rtmpService.stop()
        } else {
          await rtmpService.run(url: rtmpURL)
        }
      }
    }) {
      Text(rtmpService.isRunning ? "Stop" : "Publish")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(rtmpService.isRunning ? .red : .green)
  }
}

// MARK: - Statistics View

struct StatisticsView: View {
  let statistics: TransmissionStatistics

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Transmission Statistics")
        .font(.headline)
      LazyVGrid(columns: columns, spacing: 10) {
        StatItem(label: "Video Bitrate", value: formatBitrate(statistics.videoBitrate))
        StatItem(label: "Audio Bitrate", value: formatBitrate(statistics.audioBitrate))
        StatItem(label: "Total Sent", value: formatBytes(UInt64(statistics.totalBytesSent)))
        StatItem(label: "Video Frames", value: "\(statistics.videoFramesSent)")
        StatItem(label: "Audio Frames", value: "\(statistics.audioFramesSent)")
        StatItem(label: "Keyframes", value: "\(statistics.videoKeyFramesSent)")
        StatItem(label: "Pending Messages", value: "\(statistics.pendingMessageCount)")
        StatItem(label: "Window Usage", value: String(format: "%.1f%%", statistics.windowUtilization * 100))
      }
    }
    .padding()
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(10)
  }
}

struct StatItem: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.system(.body, design: .monospaced))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(6)
  }
}

// MARK: - Formatters

private func formatBitrate(_ bps: Double) -> String {
  let kbps = bps / 1000
  if kbps >= 1000 {
    return String(format: "%.1f Mbps", kbps / 1000)
  }
  return String(format: "%.0f kbps", kbps)
}

private func formatBytes(_ bytes: UInt64) -> String {
  let kb = Double(bytes) / 1024
  if kb >= 1024 {
    return String(format: "%.1f MB", kb / 1024)
  }
  return String(format: "%.0f KB", kb)
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
