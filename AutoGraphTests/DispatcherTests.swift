import XCTest
import Alamofire
import Crust
@testable import AutoGraph

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
    
    override func setUp() {
        super.setUp()
        
        self.mockRequestSender = MockRequestSender()
        self.subject = Dispatcher(url: "localhost", requestSender: self.mockRequestSender, responseHandler: ResponseHandler())
    }
    
    override func tearDown() {
        self.subject = nil
        self.mockRequestSender = nil
        super.tearDown()
    }
    /*
    func testForwardsRequestToSender() {
        let request = AllFilmsRequest()
        
        self.mockRequestSender.testSendRequest = { url, params, completion in
            return (url == "localhost") && (params as! [String : String] == ["query" : request.query.graphQLString])
        }
        
        XCTAssertFalse(self.mockRequestSender.expectation)
        self.subject.send(request: request, completion: { _ in })
        XCTAssertTrue(self.mockRequestSender.expectation)
    }
    
    func testHoldsRequestsWhenPaused() {
        let request = AllFilmsRequest()
        
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
        self.subject.paused = true
        self.subject.send(request: request, completion: { _ in })
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
    }
    
    func testClearsRequestsOnCancel() {
        let request = AllFilmsRequest()
        
        self.subject.paused = true
        self.subject.send(request: request, completion: { _ in })
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
        self.subject.cancelAll()
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
    }
    
    func testForwardsAndClearsPendingRequestsOnUnpause() {
        let request = AllFilmsRequest()
        
        self.mockRequestSender.testSendRequest = { url, params, completion in
            return (url == "localhost") && (params as! [String : String] == ["query" : request.query.graphQLString])
        }
        
        self.subject.paused = true
        self.subject.send(request: request, completion: { _ in })
        
        XCTAssertEqual(self.subject.pendingRequests.count, 1)
        XCTAssertFalse(self.mockRequestSender.expectation)
        
        self.subject.paused = false
        
        XCTAssertEqual(self.subject.pendingRequests.count, 0)
        XCTAssertTrue(self.mockRequestSender.expectation)
    }
 */
}
