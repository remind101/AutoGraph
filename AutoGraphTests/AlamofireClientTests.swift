import XCTest
@testable import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraphQL

class MockDataRequest: DataRequest {
    override func resume() {
        // no-op
    }
}

class AlamofireClientTests: XCTestCase {
    
    var subject: AlamofireClient!
    
    override func setUp() {
        super.setUp()
        
        self.subject = AlamofireClient(baseUrl: "localhost")
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testSetsRetrierAndAdaptorOnSession() {
        let sessionManager = Alamofire.SessionManager.default
        let authHandler = self.subject.authHandler
        XCTAssertEqual(ObjectIdentifier(sessionManager.retrier! as! AuthHandler), ObjectIdentifier(authHandler))
        XCTAssertEqual(ObjectIdentifier(sessionManager.adapter! as! AuthHandler), ObjectIdentifier(authHandler))
    }
    
    func testUpdatesRetrierAndAdaptorWithNewAuthHandler() {
        let sessionManager = Alamofire.SessionManager.default
        let authHandler = AuthHandler(baseUrl: "localhost",
                                      accessToken: nil,
                                      refreshToken: nil)
        self.subject.authHandler = authHandler
        XCTAssertEqual(ObjectIdentifier(sessionManager.retrier! as! AuthHandler), ObjectIdentifier(authHandler))
        XCTAssertEqual(ObjectIdentifier(sessionManager.adapter! as! AuthHandler), ObjectIdentifier(authHandler))
    }
    
    func testAuthenticatingSetsTokens() {
        var tokens = self.subject.authTokens
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(tokens.refreshToken)
        
        self.subject.authenticate(authTokens: ("access", "refresh"))
        tokens = self.subject.authTokens
        XCTAssertEqual(tokens.accessToken, "access")
        XCTAssertEqual(tokens.refreshToken, "refresh")
    }
    
    func testAuthHandlerDelegateCallsBackWhenAuthenticatingDirectlyIfRefreshing() {
        class MockAuthHandlerDelegate: AuthHandlerDelegate {
            var called = false
            func authHandlerBeganReauthentication(_ authHandler: AuthHandler) { }
            func authHandler(_ authHandler: AuthHandler, reauthenticatedSuccessfully: Bool) {
                called = reauthenticatedSuccessfully
            }
        }
        
        class Mock401Request: MockDataRequest {
            class Mock401Task: URLSessionTask {
                class Mock401Response: HTTPURLResponse {
                    override var statusCode: Int {
                        return 401
                    }
                }
                override var response: URLResponse? {
                    return Mock401Response(url: URL(string: "www.google.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
                }
            }
            
            override var task: URLSessionTask? {
                return Mock401Task()
            }
        }
        
        let delegate = MockAuthHandlerDelegate()
        self.subject.authHandler.delegate = delegate
        
        XCTAssertFalse(self.subject.authHandler.isRefreshing)
        
        self.subject.authenticate(authTokens: ("access", "refresh"))
        
        XCTAssertFalse(delegate.called)
        
        let request = Mock401Request(session: self.subject.sessionManager.session, requestTask: .data(nil, nil))
        self.subject.authHandler.should(self.subject.sessionManager, retry: request, with: NSError(domain: "", code: 0, userInfo: nil)) { _ in }
        
        XCTAssertTrue(self.subject.authHandler.isRefreshing)
        
        self.subject.authenticate(authTokens: ("access", "refresh"))
        
        XCTAssertTrue(delegate.called)
    }
    
    func testForwardsSendRequestToAlamofireAndRespectsHeaders() {
        
        class MockSessionManager: SessionManager {
            var success = false
            override var startRequestsImmediately: Bool {
                get {
                    return false
                }
                set { }
            }
            override func request(_ url: URLConvertible, method: HTTPMethod, parameters: Parameters?, encoding: ParameterEncoding, headers: HTTPHeaders?) -> DataRequest {
                
                success =
                    (url as! String == "url")
                    && (method == .post)
                    && (parameters! as! [String : String] == ["cool" : "param"])
                    && (encoding is JSONEncoding)
                    && (headers! == ["dumb" : "header"])
                
                let request = MockDataRequest(session: session, requestTask: .data(nil, nil))
                
                return request
            }
        }
        
        let sessionManager = MockSessionManager()
        self.subject = AlamofireClient(baseUrl: "localhost", sessionManager: sessionManager)
        self.subject.httpHeaders["dumb"] = "header"
        self.subject.sendRequest(url: "url", parameters: ["cool" : "param"], completion: { _ in })
        
        XCTAssertTrue(sessionManager.success)
    }
}
