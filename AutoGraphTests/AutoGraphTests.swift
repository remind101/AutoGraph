import XCTest
import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraph

class AutoGraphTests: XCTestCase {
    
    class MockDispatcher: Dispatcher {
        var cancelCalled = false
        override func cancelAll() {
            cancelCalled = true
        }
    }
    
    class MockClient: Client {
        public var authHandler: AuthHandler? = nil
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
        
        self.subject = AutoGraph()
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testFunctionalFileMapping() {
        let stub = AllFilmsStub()
        stub.registerStub()
        
        self.subject.send(FilmRequest()) { result in
            print(result)
        }
        
        waitFor(delay: 1.0)
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
