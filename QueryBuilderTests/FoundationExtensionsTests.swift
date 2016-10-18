import XCTest
@testable import QueryBuilder

class StringExtensionsTests: XCTestCase {
    
    func testArgumentStringDoesIncludesQuotes() {
        XCTAssertEqual("arg arg".graphQLArgument, "\"arg arg\"")
    }
}
