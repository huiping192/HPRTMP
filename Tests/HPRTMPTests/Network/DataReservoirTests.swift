import XCTest
import NIO
@testable import HPRTMP

final class DataReservoirTests: XCTestCase {
  
  func testTryRetrieveCache_empty_returnsNil() async {
    let reservoir = DataReservoir()
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNil(result)
  }
  
  func testTryRetrieveCache_withData_returnsData() async {
    let reservoir = DataReservoir()
    
    // Simulate data arriving
    await reservoir.dataArrived(data: Data([1, 2, 3]))
    
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNotNil(result)
    XCTAssertEqual(result, Data([1, 2, 3]))
    
    // Second call should return nil (cache cleared)
    let result2 = await reservoir.tryRetrieveCache()
    XCTAssertNil(result2)
  }
  
  func testMultipleDataArrived_accumulatesData() async {
    let reservoir = DataReservoir()
    
    // Send multiple data chunks
    await reservoir.dataArrived(data: Data([1, 2]))
    await reservoir.dataArrived(data: Data([3, 4]))
    await reservoir.dataArrived(data: Data([5, 6]))
    
    // All data should be accumulated
    let result = await reservoir.tryRetrieveCache()
    XCTAssertEqual(result, Data([1, 2, 3, 4, 5, 6]))
  }
  
  func testFinish_clearsCachedData() async {
    let reservoir = DataReservoir()
    
    // Add some cached data
    await reservoir.dataArrived(data: Data([1, 2, 3]))
    
    // Finish should clear the cache
    await reservoir.finish()
    
    // Cache should be empty now
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNil(result)
  }
  
  func testClose_clearsCachedData() async {
    let reservoir = DataReservoir()
    
    // Add some cached data
    await reservoir.dataArrived(data: Data([1, 2, 3]))
    
    // Close should clear the cache
    await reservoir.close()
    
    // Cache should be empty now
    let result = await reservoir.tryRetrieveCache()
    XCTAssertNil(result)
  }
}
