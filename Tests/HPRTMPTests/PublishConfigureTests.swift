import XCTest
@testable import HPRTMP

final class PublishConfigureTests: XCTestCase {
  
  func testDefaultValues() {
    let configure = PublishConfigure(
      width: 1920,
      height: 1080,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30
    )
    
    XCTAssertEqual(configure.width, 1920)
    XCTAssertEqual(configure.height, 1080)
    XCTAssertEqual(configure.videocodecid, 7)
    XCTAssertEqual(configure.audiocodecid, 10)
    XCTAssertEqual(configure.framerate, 30)
    XCTAssertNil(configure.videoDatarate)
    XCTAssertNil(configure.audioDatarate)
    XCTAssertNil(configure.audioSamplerate)
  }
  
  func testOptionalValues() {
    let configure = PublishConfigure(
      width: 1280,
      height: 720,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 60,
      videoDatarate: 5000,
      audioDatarate: 128,
      audioSamplerate: 44100
    )
    
    XCTAssertEqual(configure.videoDatarate, 5000)
    XCTAssertEqual(configure.audioDatarate, 128)
    XCTAssertEqual(configure.audioSamplerate, 44100)
  }
  
  func testMetaDataGeneration() {
    let configure = PublishConfigure(
      width: 1920,
      height: 1080,
      videocodecid: 7,
      audiocodecid: 10,
      framerate: 30,
      videoDatarate: 4500,
      audioDatarate: 96,
      audioSamplerate: 48000
    )
    
    let metaData = configure.metaData
    
    XCTAssertEqual(metaData.width, 1920)
    XCTAssertEqual(metaData.height, 1080)
    XCTAssertEqual(metaData.videocodecid, 7)
    XCTAssertEqual(metaData.audiocodecid, 10)
    XCTAssertEqual(metaData.framerate, 30)
    XCTAssertEqual(metaData.videodatarate, 4500)
    XCTAssertEqual(metaData.audiodatarate, 96)
    XCTAssertEqual(metaData.audiosamplerate, 48000)
  }
}
