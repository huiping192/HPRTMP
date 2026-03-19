import Foundation
import XCTest
import HPRTMP

// MARK: - Configuration

enum IntegrationTestConfig {
  static var rtmpTestURL: String {
    ProcessInfo.processInfo.environment["RTMP_TEST_URL"] ?? "rtmp://192.168.11.23:1936/live/test"
  }

  static var rtmpStatURL: String {
    ProcessInfo.processInfo.environment["RTMP_STAT_URL"] ?? "http://192.168.11.23:8008/api/streams"
  }

  static var rtmpAPIUsername: String {
    ProcessInfo.processInfo.environment["RTMP_API_USERNAME"] ?? "admin"
  }

  static var rtmpAPIPassword: String {
    ProcessInfo.processInfo.environment["RTMP_API_PASSWORD"] ?? "admin"
  }
}

// MARK: - Skip Helper

func skipIfNoRTMPServer(url: String = IntegrationTestConfig.rtmpTestURL) async throws {
  guard let parsedURL = URL(string: url),
        let host = parsedURL.host else {
    throw XCTSkip("Invalid RTMP_TEST_URL: \(url)")
  }
  let port = parsedURL.port ?? 1935

  // TCP probe: try to connect with a short timeout
  let isReachable = await checkTCPReachable(host: host, port: port)
  if !isReachable {
    throw XCTSkip("RTMP server not reachable at \(host):\(port) — set RTMP_TEST_URL to override")
  }
}

private func checkTCPReachable(host: String, port: Int) async -> Bool {
  await withCheckedContinuation { continuation in
    let queue = DispatchQueue(label: "tcp-probe")
    queue.async {
      let socket = Socket(host: host, port: port, timeoutSeconds: 3)
      continuation.resume(returning: socket.probe())
    }
  }
}

// MARK: - Simple TCP Socket Probe

private struct Socket {
  let host: String
  let port: Int
  let timeoutSeconds: Int

  func probe() -> Bool {
    var hints = addrinfo()
    hints.ai_socktype = SOCK_STREAM
    hints.ai_family = AF_UNSPEC

    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, "\(port)", &hints, &result) == 0, let addrInfo = result else {
      return false
    }
    defer { freeaddrinfo(addrInfo) }

    let fd = socket(addrInfo.pointee.ai_family, addrInfo.pointee.ai_socktype, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }

    var tv = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

    let connectResult = Foundation.connect(fd, addrInfo.pointee.ai_addr, addrInfo.pointee.ai_addrlen)
    return connectResult == 0
  }
}

// MARK: - Stream Verification

struct StreamInfo: Decodable {
  let publisher: PublisherInfo?

  struct PublisherInfo: Decodable {
    let active: Bool?
  }
}

/// Polls Node-Media-Server HTTP API to check if `app/stream` is active.
/// Returns:
/// - `true`  — stream confirmed active
/// - `false` — stream confirmed inactive
/// - `nil`   — API unavailable / unauthorized / parsing failed (inconclusive)
func verifyStreamActive(app: String, stream: String, retries: Int = 5) async -> Bool? {
  let urlString = IntegrationTestConfig.rtmpStatURL
  guard let url = URL(string: urlString) else { return nil }

  for _ in 0..<retries {
    switch await fetchStreamActive(url: url, app: app, stream: stream) {
    case .some(true):
      return true
    case .some(false):
      try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s, retry
    case nil:
      return nil // inconclusive, stop retrying
    }
  }
  return false
}

/// Returns `true`/`false` if the API gave a parseable answer, `nil` if the API is not usable.
private func fetchStreamActive(url: URL, app: String, stream: String) async -> Bool? {
  var request = URLRequest(url: url)
  let credentials = "\(IntegrationTestConfig.rtmpAPIUsername):\(IntegrationTestConfig.rtmpAPIPassword)"
  let encoded = Data(credentials.utf8).base64EncodedString()
  request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")

  guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
  guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200 else { return nil }
  guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

  // Node-Media-Server response: { "<app>": { "<stream>": { "publisher": { ... } } } }
  guard let appDict = json[app] as? [String: Any],
        let streamDict = appDict[stream] as? [String: Any],
        let publisher = streamDict["publisher"] as? [String: Any] else {
    return false
  }
  return publisher["active"] as? Bool ?? true
}
