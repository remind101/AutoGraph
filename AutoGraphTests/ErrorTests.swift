import XCTest
import Alamofire
import Crust
import JSONValueRX
@testable import AutoGraphQL

class ErrorTests: XCTestCase {
    func testGraphQLErrorUsesMessageForLocalizedDescription() {
        let message = "Cannot query field \"d\" on type \"Planet\"."
        let line = 18
        let column = 7
        let jsonObj: [AnyHashable : Any] = [
            "message": message,
            "locations": [
                [
                    "line": line,
                    "column": column
                ]
            ]
        ]
        
        let error = GraphQLError(json: try! JSONValue(object: jsonObj))
        XCTAssertEqual(error.errorDescription!, message)
    }
}
