import Foundation
import XCTest

@testable import HPRTMP

final class DataReservoirTests: XCTestCase {
  private var reservoir: DataReservoir!

  override func setUp() {
    super.setUp()
    reservoir = DataReservoir()
  }

  override func tearDown() async throws {
    await reservoir?.close()
    reservoir = nil
    try await super.tearDown()
  }

  func testTryRetrieveCacheEmpty() async throws {
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNil(result)
  }

  func testWaitDataReturnsCachedData() async throws {
    let testData = Data([5, 6, 7])
    await reservoir.dataArrived(data: testData)
    let result = try await reservoir.waitData()
    XCTAssertEqual(result, testData)
  }

  func testDataArrivedCachesData() async throws {
    let testData = Data([8, 9, 10])
    await reservoir.dataArrived(data: testData)
    let result = await reservoir.tryRetrieveCache()
    XCTAssertEqual(result, testData)
  }

  func testWaitDataWaitsForData() async throws {
    let waitTask = Task.detached { [reservoir] in
      try await reservoir.waitData()
    }
    try await Task.sleep(nanoseconds: 10_000_000)
    let testData = Data([1, 2, 3])
    await reservoir.dataArrived(data: testData)
    let result = try await waitTask.value
    XCTAssertEqual(result, testData)
  }

  func testDataArrivesBeforeWaitData() async throws {
    let testData = Data([1, 2, 3, 4, 5])
    await reservoir.dataArrived(data: testData)
    let result = try await reservoir.waitData()
    XCTAssertEqual(result, testData)
  }

  func testCloseCleansUp() async throws {
    await reservoir.close()
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNil(result)
  }

  func testCloseThrowsOnWaitingTask() async throws {
    let waitTask = Task.detached { [reservoir] in
      try await reservoir.waitData()
    }
    try await Task.sleep(nanoseconds: 10_000_000)
    await reservoir.close()
    do {
      _ = try await waitTask.value
      XCTFail("Expected to throw RTMPError.connectionInvalidated")
    } catch let error as RTMPError {
      XCTAssertEqual(error, RTMPError.connectionInvalidated)
    } catch {
      XCTFail("Expected RTMPError, got \(error)")
    }
  }

  func testMultipleDataArrivedAccumulate() async throws {
    await reservoir.dataArrived(data: Data([1, 2]))
    await reservoir.dataArrived(data: Data([3, 4]))
    let result = await reservoir.tryRetrieveCache()
    XCTAssertEqual(result, Data([1, 2, 3, 4]))
  }
}
