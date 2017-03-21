import XCTest
@testable import QueryBuilder

class FoundationExtensionsTests: XCTestCase {
    
    func testArgumentStringJsonEncodes() {
        XCTAssertEqual(try! "arg arg".graphQLInputValue(), "\"arg arg\"")
    }
    
    func testNSNullJsonEncodes() {
        XCTAssertEqual(try! NSNull().graphQLInputValue(), "null")
    }
    
    func testNSNumberJsonEncodes() {
        XCTAssertEqual(try! (1.1).graphQLInputValue(), "1.1")
    }
}
