import XCTest
@testable import SwiftyLibuv

class SwiftyLibuvTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //XCTAssertEqual(SwiftyLibuv().text, "Hello, World!")
    }


    static var allTests : [(String, (SwiftyLibuvTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
