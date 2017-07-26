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

class OrderedDictionaryTests: XCTestCase {
    func testsMaintainsOrder() {
        var orderedDictionary = OrderedDictionary<String, String>()
        orderedDictionary["first"] = "firstThing"
        orderedDictionary["second"] = "secondThing"
        orderedDictionary["third"] = "thirdThing"
        orderedDictionary["forth"] = "forthThing"
        
        XCTAssertEqual(orderedDictionary.values, ["firstThing", "secondThing", "thirdThing", "forthThing"])
        
        orderedDictionary["second"] = nil
        orderedDictionary["third"] = nil
        orderedDictionary["third"] = nil    // Some redundancy to test assigning `nil` twice.
        
        XCTAssertEqual(orderedDictionary.values, ["firstThing", "forthThing"])
        
        orderedDictionary["fifth"] = "fifthThing"
        
        XCTAssertEqual(orderedDictionary.values, ["firstThing", "forthThing", "fifthThing"])
    }
}
