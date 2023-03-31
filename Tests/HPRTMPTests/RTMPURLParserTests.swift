import XCTest
@testable import HPRTMP

final class RTMPURLParserTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testParseValidURLWithDefaultPort() throws {
    let parser = RTMPURLParser()
    let url = "rtmp://example.com/live/stream"
    let expectedURLInfo = RTMPURLInfo(url: URL(string: url)!, key: "live/stream", port: 1935)
    
    let result = try parser.parse(url: url)
    XCTAssertEqual(result?.url, expectedURLInfo.url)
    XCTAssertEqual(result?.key, expectedURLInfo.key)
    XCTAssertEqual(result?.port, expectedURLInfo.port)
    XCTAssertEqual(result?.host, "example.com")
  }
  func testParseValidURLWithCustomPart() throws {
    let parser = RTMPURLParser()
    let url = "rtmp://example.com:1937/live/stream"
    let expectedURLInfo = RTMPURLInfo(url: URL(string: url)!, key: "live/stream", port: 1937)
    
    let result = try parser.parse(url: url)
    XCTAssertEqual(result?.url, expectedURLInfo.url)
    XCTAssertEqual(result?.key, expectedURLInfo.key)
    XCTAssertEqual(result?.port, expectedURLInfo.port)
    XCTAssertEqual(result?.host, "example.com")
  }
  
  func testParseInvalidURL() {
    let parser = RTMPURLParser()
    let url = "http://example.com/live/stream"
    
    XCTAssertThrowsError(try parser.parse(url: url))
  }
  
}
