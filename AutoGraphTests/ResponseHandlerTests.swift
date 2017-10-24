import XCTest
import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraphQL

class ResponseHandlerTests: XCTestCase {
    
    class MockQueue: OperationQueue {
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
        
        let result = Alamofire.Result.success([
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
        
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: AllFilmsRequest().generateBinding { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .graphQL(errors: let errors) = error else {
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
        let result = Alamofire.Result<Any>.failure(NSError(domain: "", code: 0, userInfo: nil))
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: AllFilmsRequest().generateBinding { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .network(_) = error else {
                XCTFail("`error` should be an `.network` error")
                return
            }
        }, preMappingHook: { (_, _) in })
        
        XCTAssertTrue(called)
    }
    
    func testMappingErrorReturnsMappingError() {
        class AllFilmsBadRequest: AllFilmsRequest {
            override var mapping: Binding<String, FilmMapping> {
                return Binding.mapping("bad_path", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default())))
            }
        }
        
        let result = Alamofire.Result.success([ "dumb" : "data" ] as Any)
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        
        var called = false
        
        self.subject.handle(response: response, objectBinding: AllFilmsBadRequest().generateBinding { result in
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
        class MockRequest: AllFilmsRequest {
            var mappingCalled = false
            var called = false
            override func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws {
                called = !mappingCalled
            }
            
            override var mapping: Binding<String, FilmMapping> {
                mappingCalled = true
                return super.mapping
            }
        }
        
        let result = Alamofire.Result.success([ "dumb" : "data" ] as Any)
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        let request = MockRequest()
        
        self.subject.handle(response: response, objectBinding: request.generateBinding(completion: { _ in }), preMappingHook: request.didFinishRequest)
        
        XCTAssertTrue(request.called)
    }
}
