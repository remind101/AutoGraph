import XCTest
import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraphQL

struct MockNetworkError: NetworkError {
    let statusCode: Int
    let underlyingError: GraphQLError
}

public extension AutoGraphQL.Request {
    func willSend() throws { }
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    func didFinish(result: AutoGraphQL.Result<SerializedObject>) throws { }
}

class FilmRequestWithLifeCycle: FilmRequest {
    var willSendCalled = false
    override func willSend() throws {
        willSendCalled = true
    }
    
    var didFinishCalled = false
    override func didFinish(result: AutoGraphQL.Result<FilmRequest.SerializedObject>) throws {
        didFinishCalled = true
    }
}

private let kDelay = 0.5

class AutoGraphTests: XCTestCase {
    class MockDispatcher: Dispatcher {
        var cancelCalled = false
        override func cancelAll() {
            cancelCalled = true
        }
    }
    
    class MockClient: Client {
        public var sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
        public var authTokens: AuthTokens = ("", "")
        public var authHandler: AuthHandler = AuthHandler(baseUrl: "localhost", accessToken: nil, refreshToken: nil)
        public var baseUrl: String = ""

        var cancelCalled = false
        func cancelAll() {
            cancelCalled = true
        }
        
        func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ()) { }
    }
    
    var subject: AutoGraph!
    
    override func setUp() {
        super.setUp()
        let config = RLMRealmConfiguration.default()
        var url = config.fileURL!
        if url.lastPathComponent == "default.realm" {
            url.deleteLastPathComponent()
        }
        config.fileURL = url
        RLMRealmConfiguration.setDefault(config)
        _ = RLMRealm.default()
        self.subject = AutoGraph()
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testFunctionalAllFilmsRequest() {
        let stub = AllFilmsStub()
        stub.registerStub()
        
        var called = false
        self.subject.send(AllFilmsRequest()) { result in
            called = true
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testFunctionalSingleFilmRequest() {
        let stub = FilmStub()
        stub.registerStub()
        
        var called = false
        self.subject.send(FilmRequest()) { result in
            called = true
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testFunctionalSingleFilmThreadUnconfinedRequest() {
        let stub = FilmThreadUnconfinedStub()
        stub.registerStub()
        
        var called = false
        self.subject.send(FilmThreadUnconfinedRequest()) { result in
            called = true
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testFunctionalVariableFilmRequest() {
        let stub = VariableFilmStub()
        stub.registerStub()
        
        var called = false
        self.subject.send(VariableFilmRequest()) { result in
            called = true
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testFunctional401Request() {
        class Film401Stub: FilmStub {
            override var jsonFixtureFile: String? {
                get { return "Film401" }
                set { }
            }
        }
        
        self.subject.networkErrorParser = { gqlError in
            guard gqlError.message == "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}" else {
                return nil
            }
            return MockNetworkError(statusCode: 401, underlyingError: gqlError)
        }
        
        let stub = Film401Stub()
        stub.registerStub()
        
        let request = FilmRequest()
        
        var called = false
        self.subject.send(request) { result in
            called = true
            
            XCTFail()
        }
        
        waitFor(delay: kDelay)
        XCTAssertFalse(called)
        
        XCTAssertTrue(self.subject.dispatcher.paused)
        XCTAssertTrue(self.subject.authHandler.isRefreshing)
        XCTAssertTrue(( try! self.subject.dispatcher.pendingRequests.first!.queryDocument.graphQLString()) == (try! request.queryDocument.graphQLString()))
    }
    
    func testFunctional401RequestNotHandled() {
        class Film401Stub: FilmStub {
            override var jsonFixtureFile: String? {
                get { return "Film401" }
                set { }
            }
        }
        
        self.subject.networkErrorParser = { gqlError in
            guard gqlError.message == "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}" else {
                return nil
            }
            // Not passing back a 401 status code so won't be registered as an auth error.
            return MockNetworkError(statusCode: -1, underlyingError: gqlError)
        }
        
        let stub = Film401Stub()
        stub.registerStub()
        
        let request = FilmRequest()
        
        var called = false
        self.subject.send(request) { result in
            called = true
            
            guard
                case .failure(let failureError) = result,
                case let error as AutoGraphError = failureError,
                case .network(let baseError, let statusCode, _, let underlying) = error,
                case .some(.graphQL(errors: let underlyingErrors)) = underlying,
                case let networkError as NetworkError = baseError,
                networkError.statusCode == -1,
                networkError.underlyingError == underlyingErrors.first,
                networkError.statusCode == statusCode
            else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
        
        XCTAssertFalse(self.subject.dispatcher.paused)
        XCTAssertFalse(self.subject.authHandler.isRefreshing)
        XCTAssertEqual(self.subject.dispatcher.pendingRequests.count, 0)
    }
    
    func testFunctionalLifeCycle() {
        let stub = FilmStub()
        stub.registerStub()
        
        let request = FilmRequestWithLifeCycle()
        self.subject.send(request, completion: { _ in })
        
        waitFor(delay: kDelay)
        XCTAssertTrue(request.willSendCalled)
        XCTAssertTrue(request.didFinishCalled)
    }
    
    func testFunctionalGlobalLifeCycle() {
        class GlobalLifeCycleMock: GlobalLifeCycle {
            var willSendCalled = false
            override func willSend<R : AutoGraphQL.Request>(request: R) throws {
                willSendCalled = request is FilmRequest
            }
            
            var didFinishCalled = false
            override func didFinish<SerializedObject>(result: AutoGraphQL.Result<SerializedObject>) throws {
                guard case .success(let value) = result else {
                    return
                }
                didFinishCalled = value is Film
            }
        }
        
        let lifeCycle = GlobalLifeCycleMock()
        self.subject.lifeCycle = lifeCycle
        
        let stub = FilmStub()
        stub.registerStub()
        
        let request = FilmRequest()
        self.subject.send(request, completion: { _ in })
        
        waitFor(delay: kDelay)
        XCTAssertTrue(lifeCycle.willSendCalled)
        XCTAssertTrue(lifeCycle.didFinishCalled)
    }
    
    func testCancelAllCancelsDispatcherAndClient() {
        let mockClient = MockClient()
        let mockDispatcher = MockDispatcher(url: "blah", requestSender: mockClient, responseHandler: ResponseHandler())
        self.subject = AutoGraph(client: mockClient, dispatcher: mockDispatcher)
        
        self.subject.cancelAll()
        
        XCTAssertTrue(mockClient.cancelCalled)
        XCTAssertTrue(mockDispatcher.cancelCalled)
    }
    
    func testAuthHandlerBeganReauthenticationPausesDispatcher() {
        XCTAssertFalse(self.subject.dispatcher.paused)
        self.subject.authHandlerBeganReauthentication(AuthHandler(baseUrl: "blah", accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
    }
    
    func testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher() {
        self.subject.authHandlerBeganReauthentication(AuthHandler(baseUrl: "blah", accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
        self.subject.authHandler(AuthHandler(baseUrl: "blah", accessToken: nil, refreshToken: nil), reauthenticatedSuccessfully: true)
        XCTAssertFalse(self.subject.dispatcher.paused)
    }
    
    func testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll() {
        let mockClient = MockClient()
        let mockDispatcher = MockDispatcher(url: "blah", requestSender: mockClient, responseHandler: ResponseHandler())
        self.subject = AutoGraph(client: mockClient, dispatcher: mockDispatcher)
        
        self.subject.authHandlerBeganReauthentication(AuthHandler(baseUrl: "blah", accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
        self.subject.authHandler(AuthHandler(baseUrl: "blah", accessToken: nil, refreshToken: nil), reauthenticatedSuccessfully: false)
        XCTAssertTrue(self.subject.dispatcher.paused)
        
        XCTAssertTrue(mockClient.cancelCalled)
        XCTAssertTrue(mockDispatcher.cancelCalled)
    }
    
    func testTriggeringReauthenticationPausesSystem() {
        self.subject.triggerReauthentication()
        self.waitFor(delay: 0.01)
        XCTAssertTrue(self.subject.dispatcher.paused)
        XCTAssertTrue(self.subject.authHandler.isRefreshing)
    }
    
    func waitFor(delay: TimeInterval) {
        let expectation = self.expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: delay + 1.0, handler: { error in
            if let error = error {
                print(error)
            }
        })
    }
}
