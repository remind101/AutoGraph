import XCTest
@testable import Alamofire
import JSONValueRX
@testable import AutoGraphQL

class MockDataRequest: DataRequest {
    @discardableResult
    override public func resume() -> Self {
        // no-op
        return self
    }
}

class AlamofireClientTests: XCTestCase {
    
    var subject: AlamofireClient!
    
    override func setUp() {
        super.setUp()
        
        self.subject = try! AlamofireClient(url: "localhost", session: Session(interceptor: AuthHandler()))
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testSetsAuthHandlerOnSession() {
        let authHandler = self.subject.authHandler
        XCTAssertEqual(ObjectIdentifier(self.subject.session.interceptor as! AuthHandler), ObjectIdentifier(authHandler!))
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
        self.subject.authHandler!.delegate = delegate
        
        XCTAssertFalse(self.subject.authHandler!.isRefreshing)
        
        self.subject.authenticate(authTokens: ("access", "refresh"))
        
        XCTAssertFalse(delegate.called)
                
        let request = Mock401Request(convertible: URLRequest(url: URL(string: "www.google.com")!),
                                     underlyingQueue: self.subject.session.rootQueue,
                                     serializationQueue: self.subject.session.serializationQueue,
                                     eventMonitor: self.subject.session.eventMonitor,
                                     interceptor: self.subject.session.interceptor,
                                     delegate: self.subject.session)
        
        self.subject.authHandler?.retry(request, for: self.subject.session, dueTo: NSError(domain: "", code: 0, userInfo: nil), completion: { _ in })
        
        XCTAssertTrue(self.subject.authHandler!.isRefreshing)
        self.subject.authenticate(authTokens: ("access", "refresh"))
        XCTAssertTrue(delegate.called)
    }
    
    func testForwardsSendRequestToAlamofireAndRespectsHeaders() {
        
        class MockSession: Session {
            var success = false
            
            override func request(_ convertible: URLConvertible, method: HTTPMethod = .get, parameters: Parameters? = nil, encoding: ParameterEncoding = URLEncoding.default, headers: HTTPHeaders? = nil, interceptor: RequestInterceptor? = nil) -> DataRequest {
                
                success =
                    (convertible as! URL == URL(string: "localhost")!)
                    && (method == .post)
                    && (parameters! as! [String : String] == ["cool" : "param"])
                    && (encoding is JSONEncoding)
                    && (headers!.dictionary == ["dumb" : "header"])
                
                let request = MockDataRequest(convertible: try! URLRequest(url: convertible,
                                                                           method: method,
                                                                           headers: headers),
                                              underlyingQueue: self.rootQueue,
                                              serializationQueue: self.serializationQueue,
                                              eventMonitor: self.eventMonitor,
                                              interceptor: self.interceptor,
                                              delegate: self)
                
                return request
            }
        }
        
        let session = MockSession(startRequestsImmediately: false, interceptor: AuthHandler())
        self.subject = try! AlamofireClient(url: "localhost", session: session)
        self.subject.httpHeaders["dumb"] = "header"
        self.subject.sendRequest(parameters: ["cool" : "param"], completion: { _ in })
        
        XCTAssertTrue(session.success)
    }
}
