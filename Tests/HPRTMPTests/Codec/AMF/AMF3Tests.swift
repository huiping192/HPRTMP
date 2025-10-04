//
//  AMF3Tests.swift
//  
//
//  Created by 郭 輝平 on 2023/03/27.
//

import XCTest
@testable import HPRTMP

final class AMF3Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // test amf3 encode
     func testAMF3Encode() throws {
        let value = 123
        let data = value.amf3Value
        XCTAssertEqual(data, Data([0x04, 0x7b]))
    }
}
