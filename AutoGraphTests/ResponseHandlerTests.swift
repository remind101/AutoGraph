import XCTest
import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraph

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
        
        self.subject.handle(response: response, mapping: { AllFilmsRequest().mapping }) { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .graphQL(errors: let errors) = error else {
                XCTFail("`error` should be an `.mapping` error")
                return
            }
            
            XCTAssertEqual(errors.count, 1)
            
            let gqlError = errors[0]
            XCTAssertEqual(gqlError.message, message)
            XCTAssertEqual(gqlError.locations.count, 1)
            
            let location = gqlError.locations[0]
            XCTAssertEqual(location.line, line)
            XCTAssertEqual(location.column, column)
        }
        
        XCTAssertTrue(called)
    }
    
    func testNetworkErrorReturnsNetworkError() {
        let result = Alamofire.Result<Any>.failure(NSError(domain: "", code: 0, userInfo: nil))
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        
        var called = false
        
        self.subject.handle(response: response, mapping: { AllFilmsRequest().mapping }) { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .network(_) = error else {
                XCTFail("`error` should be an `.network` error")
                return
            }
        }
        
        XCTAssertTrue(called)
    }
    
    func testMappingErrorReturnsMappingError() {
        class AllFilmsBadRequest: AllFilmsRequest {
            override var mapping: AllFilmsMapping {
                let adaptor = RealmArrayAdaptor<Film>(realm: RLMRealm.default())
                return AllFilmsBadMapping(adaptor: adaptor)
            }
        }
        
        class AllFilmsBadMapping: AllFilmsMapping {
            open override var keyPath: Keypath {
                return "bad_path"
            }
        }
        
        let result = Alamofire.Result.success([ "dumb" : "data" ] as Any)
        let response = DataResponse(request: nil, response: nil, data: nil, result: result)
        
        var called = false
        
        self.subject.handle(response: response, mapping: { AllFilmsBadRequest().mapping }) { result in
            called = true
            
            guard case .failure(let error as AutoGraphError) = result else {
                XCTFail("`result` should be an `AutoGraphError`")
                return
            }
            
            guard case .mapping(error: _) = error else {
                XCTFail("`error` should be an `.mapping` error")
                return
            }
        }
        
        XCTAssertTrue(called)
    }
}
