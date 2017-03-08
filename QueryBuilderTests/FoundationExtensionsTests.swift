import XCTest
@testable import QueryBuilder

class StringExtensionsTests: XCTestCase {
    
    func testArgumentStringDoesIncludeQuotes() {
        XCTAssertEqual(try! "arg arg".graphQLInputValue(), "\"arg arg\"")
    }
}
