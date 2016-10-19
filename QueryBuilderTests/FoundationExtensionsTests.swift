import XCTest
@testable import QueryBuilder

class StringExtensionsTests: XCTestCase {
    
    func testArgumentStringDoesIncludeQuotes() {
        XCTAssertEqual("arg arg".graphQLArgument, "\"arg arg\"")
    }
}
