import Foundation
import XCTest
import HPRTMP

// MARK: - Unique Stream URL

func uniqueStreamURL(prefix: String = "test") -> String {
  let base = IntegrationTestConfig.rtmpTestURL
  guard let url = URL(string: base),
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
    return base
  }
  let uuid = UUID().uuidString.prefix(8).lowercased()
  let pathParts = url.pathComponents.filter { $0 != "/" }
  let app = pathParts.first ?? "live"
  components.path = "/\(app)/\(prefix)-\(uuid)"
  return components.url?.absoluteString ?? base
}

// MARK: - Configuration

enum IntegrationTestConfig {
  static var rtmpTestURL: String {
    ProcessInfo.processInfo.environment["RTMP_TEST_URL"] ?? "rtmp://192.168.11.23:1936/live/test"
  }

  static var rtmpStatURL: String {
    ProcessInfo.processInfo.environment["RTMP_STAT_URL"] ?? "http://192.168.11.23:8008"
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

/// Polls Node-Media-Server v4 HTTP API to check if `app/stream` is active.
/// Returns:
/// - `true`  — stream confirmed active
/// - `false` — stream confirmed inactive
/// - `nil`   — API unavailable / unauthorized / parsing failed (inconclusive)
func verifyStreamActive(app: String, stream: String, retries: Int = 5) async -> Bool? {
  guard let baseURL = URL(string: IntegrationTestConfig.rtmpStatURL) else { return nil }

  guard let token = await fetchJWTToken(baseURL: baseURL) else { return nil }

  for _ in 0..<retries {
    switch await fetchStreamActive(baseURL: baseURL, token: token, app: app, stream: stream) {
    case .some(true):
      return true
    case .some(false):
      try? await Task.sleep(nanoseconds: 500_000_000)
    case nil:
      return nil
    }
  }
  return false
}

/// POST /api/v1/login → JWT token, nil on failure.
private func fetchJWTToken(baseURL: URL) async -> String? {
  let loginURL = baseURL.appendingPathComponent("api/v1/login")
  var request = URLRequest(url: loginURL)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")

  let body: [String: String] = [
    "username": IntegrationTestConfig.rtmpAPIUsername,
    "password": IntegrationTestConfig.rtmpAPIPassword
  ]
  guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
  request.httpBody = bodyData

  guard let (data, response) = try? await URLSession.shared.data(for: request),
        let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let dataDict = json["data"] as? [String: Any],
        let token = dataDict["token"] as? String else { return nil }

  return token
}

/// GET /api/v1/streams with Bearer token; handles both NMS v4 response formats.
private func fetchStreamActive(baseURL: URL, token: String, app: String, stream: String) async -> Bool? {
  let streamsURL = baseURL.appendingPathComponent("api/v1/streams")
  var request = URLRequest(url: streamsURL)
  request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

  guard let (data, response) = try? await URLSession.shared.data(for: request),
        let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

  let payload = json["data"] ?? json

  // Format A: {"data": [{"app":"live","stream":"xxx",...}]}
  if let list = payload as? [[String: Any]] {
    return list.contains { ($0["app"] as? String) == app && ($0["stream"] as? String) == stream }
  }

  // Format B: {"data": {"live": {"xxx": {...}}}} or top-level {"live": {"xxx": {...}}}
  if let dict = payload as? [String: Any],
     let appDict = dict[app] as? [String: Any] {
    return appDict[stream] != nil
  }

  return nil
}
