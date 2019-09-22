import XCTest
@testable import Airframe

final class AirframeTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Airframe().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
