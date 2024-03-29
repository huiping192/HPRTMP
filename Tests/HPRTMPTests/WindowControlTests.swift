
import XCTest
@testable import HPRTMP

final class WindowControlTests: XCTestCase {
      
  func testAddInBytesCount() async {
    var inbytesCount: UInt32 = 0
    let windowControl = WindowControl()
    
    await windowControl.setWindowSize(250000)
    await windowControl.setInBytesWindowEvent { totalInBytes in
      inbytesCount = totalInBytes
    }
        
    await windowControl.addInBytesCount(250000)
    
    let count = await windowControl.totalInBytesCount
    let seq = await windowControl.totalInBytesSeq
    XCTAssertEqual(count, 250000)
    XCTAssertEqual(seq, 2)
    XCTAssertEqual(inbytesCount, 250000)

    
    await windowControl.addInBytesCount(250000)
    let count2 = await windowControl.totalInBytesCount
    let seq2 = await windowControl.totalInBytesSeq
    XCTAssertEqual(count2, 500000)
    XCTAssertEqual(seq2, 3)
    XCTAssertEqual(inbytesCount, 500000)
  }
  
  func testAddOutBytesCount() async {
    let windowControl = WindowControl()
    await windowControl.setWindowSize(250000)

    await windowControl.addOutBytesCount(250000)
    
    let count = await windowControl.totalOutBytesCount
    let seq = await windowControl.totalOutBytesSeq
    XCTAssertEqual(count, 250000)
    XCTAssertEqual(seq, 2)

    
    await windowControl.addOutBytesCount(250000)
    let count2 = await windowControl.totalOutBytesCount
    let seq2 = await windowControl.totalOutBytesSeq
    XCTAssertEqual(count2, 500000)
    XCTAssertEqual(seq2, 3)
  }
  
  func testShouldWaitAcknowledgement() async {
    let windowControl = WindowControl()

    await windowControl.setWindowSize(240000)
    
    for _ in 0..<5 {
      await windowControl.addOutBytesCount(50000)
    }
    var shouldWaitAcknowledgement = await windowControl.shouldWaitAcknowledgement
    XCTAssertTrue(shouldWaitAcknowledgement)
    
    await windowControl.updateReceivedAcknowledgement(250000)
    shouldWaitAcknowledgement = await windowControl.shouldWaitAcknowledgement
    XCTAssertFalse(shouldWaitAcknowledgement)
  }
}
