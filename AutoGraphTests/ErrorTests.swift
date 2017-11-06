import XCTest
import Alamofire
import Crust
import JSONValueRX
@testable import AutoGraphQL

struct MockNetworkError: NetworkError {
    let statusCode: Int
    let underlyingError: GraphQLError
}

class ErrorTests: XCTestCase {
    func testInvalidResponseLocalizedErrorDoesntCrash() {
        let description = AutoGraphError.invalidResponse.localizedDescription
        XCTAssertGreaterThan(description.count, 0)
    }
    
    func testAutoGraphErrorGraphQLErrorUsesMessages() {
        let message1 = "Cannot query field \"d\" on type \"Planet\"."
        let message2 = "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}"
        let line = 18
        let column = 7
        let jsonObj: [AnyHashable : Any] = [
            "errors" : [
                [
                    "message": message1,
                    "locations": [
                        [
                            "line": line,
                            "column": column
                        ]
                    ]
                ],
                [
                    "message": message2,
                    "locations": [
                        [
                            "line": line,
                            "column": column
                        ]
                    ]
                ]
            ]
        ]
        
        let json = try! JSONValue(object: jsonObj)
        let error = AutoGraphError(graphQLResponseJSON: json, networkErrorParser: nil)!
        XCTAssertEqual(error.errorDescription!, "\(message1)\n\(message2)")
        XCTAssertEqual(error.localizedDescription, "\(message1)\n\(message2)")
    }
    
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
        XCTAssertEqual(error.localizedDescription, message)
    }
    
    func testAutoGraphErrorProducesNetworkErrorForNetworkErrorParserMatch() {
        let message = "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}"
        let line = 18
        let column = 7
        let jsonObj: [AnyHashable : Any] = [
            "errors" : [
                [
                    "message": message,
                    "locations": [
                        [
                            "line": line,
                            "column": column
                        ]
                    ]
                ]
            ]
        ]
        
        let json = try! JSONValue(object: jsonObj)
        let error = AutoGraphError(graphQLResponseJSON: json) { gqlError -> NetworkError? in
            guard message == gqlError.message else {
                return nil
            }
            
            return MockNetworkError(statusCode: 401, underlyingError: gqlError)
        }
        
        guard
            case .some(.network(let baseError, let statusCode, _, let underlying)) = error,
            case .some(.graphQL(errors: let underlyingErrors)) = underlying,
            case let networkError as NetworkError = baseError,
            networkError.statusCode == 401,
            networkError.underlyingError == underlyingErrors.first,
            networkError.statusCode == statusCode
        else {
            XCTFail()
            return
        }
    }
}
