import XCTest
import Alamofire
import Crust
@testable import AutoGraphQL

class DispatcherTests: XCTestCase {
    
    var subject: Dispatcher!
    var mockRequestSender: MockRequestSender!
    
    class MockRequestSender: RequestSender {
        
        var expectation: Bool = false
        
        var testSendRequest: ((_ url: String, _ parameters: [String : Any], _ completion: @escaping (DataResponse<Any>) -> ()) -> Bool)?
        
        func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ()) {
            self.expectation = testSendRequest?(url, parameters, completion) ?? false
        }
    }
    
    class MockQueue: OperationQueue {
        override func addOperation(_ op: Foundation.Operation) {
            op.start()
        }
    }
    
    override func setUp() {
        super.setUp()
        
        self.mockRequestSender = MockRequestSender()
        self.subject = Dispatcher(url: "localhost", requestSender: self.mockRequestSender, responseHandler: ResponseHandler(queue: MockQueue(), callbackQueue: MockQueue()))
    }
    
    override func tearDown() {
        self.subject = nil
        self.mockRequestSender = nil
        super.tearDown()
    }
    
    func testForwardsRequestToSender() {
        let request = AllFilmsRequest()
        let sendable = Sendable(dispatcher: self.subject, request: request, objectBindingPromise: { _ in request.generateBinding(completion: { _ in }) }, globalWillSend: { _ in })
        
        self.mockRequestSender.testSendRequest = { url, params, completion in
            return (url == "localhost") && (params as! [String : String] == ["query" : try! request.query.graphQLString()])
        }
        
        XCTAssertFalse(self.mockRequestSender.expectation)
        self.subject.send(sendable: sendable)
        XCTAssertTrue(self.mockRequestSender.expectation)
    }
    
    func testHoldsRequestsWhenPaused() {
        let request = AllFilmsRequest()
        let sendable = Sendable(dispatcher: self.subject, request: request, objectBindingPromise: { _ in request.generateBinding(completion: { _ in }) }, globalWillSend: { _ in })
        
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
        self.subject.paused = true
        self.subject.send(sendable: sendable)
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
    }
    
    func testClearsRequestsOnCancel() {
        let request = AllFilmsRequest()
        let sendable = Sendable(dispatcher: self.subject, request: request, objectBindingPromise: { _ in request.generateBinding(completion: { _ in }) }, globalWillSend: { _ in })
        
        self.subject.paused = true
        self.subject.send(sendable: sendable)
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
        self.subject.cancelAll()
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
    }
    
    func testForwardsAndClearsPendingRequestsOnUnpause() {
        let request = AllFilmsRequest()
        let sendable = Sendable(dispatcher: self.subject, request: request, objectBindingPromise: { _ in request.generateBinding(completion: { _ in }) }, globalWillSend: { _ in })
        
        self.mockRequestSender.testSendRequest = { url, params, completion in
            return (url == "localhost") && (params as! [String : String] == ["query" : try! request.query.graphQLString()])
        }
        
        self.subject.paused = true
        self.subject.send(sendable: sendable)
        
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
        XCTAssertFalse(self.mockRequestSender.expectation)
        
        self.subject.paused = false
        
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
        XCTAssertTrue(self.mockRequestSender.expectation)
    }
    
    class BadRequest: AutoGraphQL.Request {
        struct BadQuery: GraphQLQuery {
            func graphQLString() throws -> String {
                throw NSError(domain: "error", code: -1, userInfo: nil)
            }
        }
        
        let query = BadQuery()
        let variables: [AnyHashable : Any]? = nil
        
        var threadAdapter: RealmThreadAdapter? = nil
        
        var mapping: Binding<String, FilmMapping> {
            return Binding.mapping("data.film", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default())))
        }
        
        let mappingKeys = AllKeys<FilmKey>()
    }
    
    func testFailureReturnsToCaller() {
        let request = BadRequest()
        var called = false
        let objectBinding = request.generateBinding { result in
            guard case .failure(_) = result else {
                XCTFail()
                return
            }
            called = true
        }
        
        let sendable = Sendable(dispatcher: self.subject, request: request, objectBindingPromise: { _ in objectBinding }, globalWillSend: { _ in })
        
        self.subject.send(sendable: sendable)
        XCTAssertTrue(called)
    }
}
