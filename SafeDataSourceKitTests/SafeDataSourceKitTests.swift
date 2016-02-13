//
//  SafeDataSourceKitTests.swift
//  SafeDataSourceKitTests
//
//  Created by Rene Cacheaux on 2/12/16.
//  Copyright © 2016 rcach. All rights reserved.
//

import XCTest
@testable import SafeDataSourceKit

class SafeDataSourceKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
      let ex = expectationWithDescription(".")

      let queue = SerialUIOperationQueue()
      queue.addOperationWithBlock {
        print("hi")
        ex.fulfill()
      }

      waitForExpectationsWithTimeout(1000000, handler: nil)


    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
