import XCTest
import Alamofire
import JSONValueRX
@testable import AutoGraphQL

class ResponseHandlerTests: XCTestCase {
    
    class MockQueue: OperationQueue, @unchecked Swift.Sendable {
        override func addOperation(_ op: Foundation.Operation) {
            op.start()
        }
    }
    
    var subject: ResponseHandler!
    
    override func setUp() {
        super.setUp()
        
        self.subject = ResponseHandler(queue: MockQueue(), callbackQueue: MockQueue())
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testErrorsJsonReturnsGraphQLError() {
        let message = "Cannot query field \"d\" on type \"Planet\"."
        let line = 18
        let column = 7
        
        let result = Result<Any, AFError>.success([
            "dumb" : "data",
            "errors": [
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
            ] as Any)
        
        let response = AFDataResponse(request: nil, response: nil, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: FilmRequest().generateBinding { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .graphQL(errors: let errors, _) = error else {
                XCTFail("`error` should be an `.graphQL` error")
                return
            }
            
            XCTAssertEqual(errors.count, 1)
            
            let gqlError = errors[0]
            XCTAssertEqual(gqlError.message, message)
            XCTAssertEqual(gqlError.locations.count, 1)
            
            let location = gqlError.locations[0]
            XCTAssertEqual(location.line, line)
            XCTAssertEqual(location.column, column)
        }, preMappingHook: { (_, _) in })
        
        XCTAssertTrue(called)
    }
    
    func testNetworkErrorReturnsNetworkError() {
        let result = Result<Any, AFError>.failure(AFError.sessionTaskFailed(error: NSError(domain: "", code: 0, userInfo: nil)))
        let response = AFDataResponse(request: nil, response: nil, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: FilmRequest().generateBinding { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .network = error else {
                XCTFail("`error` should be an `.network` error")
                return
            }
        }, preMappingHook: { (_, _) in })
        
        XCTAssertTrue(called)
    }
    
    func testMappingErrorReturnsMappingError() {
        class FilmBadRequest: FilmRequest {
        }
        
        let result = Result<Any, AFError>.success([ "dumb" : "data" ] as Any)
        let response = AFDataResponse(request: nil, response: nil, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: FilmBadRequest().generateBinding { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .mapping(error: _) = error else {
                XCTFail("`error` should be an `.mapping` error")
                return
            }
        }, preMappingHook: { (_, _) in })
        
        XCTAssertTrue(called)
    }
    
    func testPreMappingHookCalledBeforeMapping() {
        class MockRequest: FilmRequest {
            var called = false
            override func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws {
                called = true
            }
        }
        
        let result = Result<Any, AFError>.success([ "dumb" : "data" ] as Any)
        let response = AFDataResponse(request: nil, response: nil, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        let request = MockRequest()
        
        self.subject.handle(response: response, objectBinding: request.generateBinding(completion: { _ in }), preMappingHook: request.didFinishRequest)
        
        XCTAssertTrue(request.called)
    }
    
    func testResponseReturnedFromNetworkError() {
        let httpResponse = HTTPURLResponse(url: URL(string: "www.test.com")!, statusCode: 400, httpVersion: nil, headerFields: ["request_id" : "1234"])
        let result = Result<Any, AFError>.failure(AFError.sessionTaskFailed(error: NSError(domain: "", code: 0, userInfo: nil)))
        let response = AFDataResponse(request: nil, response: httpResponse, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var requestId: String?
        
        self.subject.handle(response: response, objectBinding: FilmRequest().generateBinding { result in
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .network(_,_,let response, _) = error else {
                XCTFail("`error` should be an `.network` error")
                return
            }
            
            requestId = response?.allHeaderFields["request_id"] as? String
        }, preMappingHook: { (_, _) in })
        
        XCTAssertNotNil(requestId)
        XCTAssertEqual(requestId, "1234")
    }
    
    func testResponseReturnedFromMappingError() {
        class FilmBadRequest: FilmRequest {
        }
        
        let httpResponse = HTTPURLResponse(url: URL(string: "www.test.com")!, statusCode: 400, httpVersion: nil, headerFields: ["request_id" : "1234"])
        let result = Result<Any, AFError>.success([ "dumb" : "data" ] as Any)
        let response = AFDataResponse(request: nil, response: httpResponse, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var requestId: String?
        
        self.subject.handle(response: response, objectBinding: FilmBadRequest().generateBinding { result in
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .mapping(error: _, let response) = error else {
                XCTFail("`error` should be an `.mapping` error")
                return
            }
            
            requestId = response?.allHeaderFields["request_id"] as? String
        }, preMappingHook: { (_, _) in })
        
        XCTAssertNotNil(requestId)
        XCTAssertEqual(requestId, "1234")
    }
    
    func testResponseReturnedFromGraphQLError() {
        let message = "Cannot query field \"d\" on type \"Planet\"."
        let line = 18
        let column = 7
        
        let result = Result<Any, AFError>.success([
            "dumb" : "data",
            "errors": [
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
            ] as Any)
        
        let httpResponse = HTTPURLResponse(url: URL(string: "www.test.com")!, statusCode: 400, httpVersion: nil, headerFields: ["request_id" : "1234"])
        let response = AFDataResponse(request: nil, response: httpResponse, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var requestId: String?
        
        self.subject.handle(response: response, objectBinding: FilmRequest().generateBinding { result in
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .graphQL(errors: _, let response) = error else {
                XCTFail("`error` should be an `.graphQL` error")
                return
            }
            
             requestId = response?.allHeaderFields["request_id"] as? String
        }, preMappingHook: { (_, _) in })
        
        XCTAssertNotNil(requestId)
        XCTAssertEqual(requestId, "1234")
    }
    
    func testResponseReturnedFromInvalidResponseError() {
        let result = Result<Any, AFError>.success([
            "dumb" : "data",
            "errors": "Invalid",
            ] as Any)
        
        let httpResponse = HTTPURLResponse(url: URL(string: "www.test.com")!, statusCode: 200, httpVersion: nil, headerFields: ["request_id" : "1234"])
        let response = AFDataResponse(request: nil, response: httpResponse, data: nil, metrics: nil, serializationDuration: 0.0, result: result)
        
        var requestId: String?
        
        self.subject.handle(response: response, objectBinding: FilmRequest().generateBinding { result in
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .invalidResponse(let response) = error else {
                XCTFail("`error` should be an `.network` error")
                return
            }
            
            requestId = response?.allHeaderFields["request_id"] as? String
        }, preMappingHook: { (_, _) in })
        
        XCTAssertNotNil(requestId)
        XCTAssertEqual(requestId, "1234")
    }
}
