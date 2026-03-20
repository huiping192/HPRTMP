import XCTest
@testable import HPRTMP

final class RTMPPlayerSessionTests: XCTestCase {

  func testPlayerSessionCanBeCreated() {
    let session = RTMPPlayerSession()
    XCTAssertNotNil(session)
  }

  func testStopCanBeCalledOnNewSession() async {
    let session = RTMPPlayerSession()
    await session.stop()
  }
}
