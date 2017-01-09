import XCTest
@testable import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraph

class AlamofireClientTests: XCTestCase {
    
    var subject: AlamofireClient!
    
    override func setUp() {
        super.setUp()
        
        self.subject = AlamofireClient(baseUrl: "localhost")
    }
    
    func testSetsRetrieAndAdaptorOnSession() {
        let sessionManager = Alamofire.SessionManager.default
        let authHandler = self.subject.authHandler!
        XCTAssertEqual(ObjectIdentifier(sessionManager.retrier! as! AuthHandler), ObjectIdentifier(authHandler))
        XCTAssertEqual(ObjectIdentifier(sessionManager.adapter! as! AuthHandler), ObjectIdentifier(authHandler))
    }
    
    func testSettingTokens() {
        var tokens = self.subject.tokens
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(tokens.refreshToken)
        
        self.subject.tokens = ("access", "refresh")
        tokens = self.subject.tokens
        XCTAssertEqual(tokens.accessToken, "access")
        XCTAssertEqual(tokens.refreshToken, "refresh")
    }
    
    func testForwardsSendRequestToAlamofire() {
        class MockDataRequest: DataRequest {
            override func resume() {
                // no-op
            }
        }
        
        class MockSessionManager: SessionManager {
            var success = false
            override var startRequestsImmediately: Bool {
                get {
                    return false
                }
                set { }
            }
            override func request(_ url: URLConvertible, method: HTTPMethod, parameters: Parameters?, encoding: ParameterEncoding, headers: HTTPHeaders?) -> DataRequest {
                
                success = (url as! String == "url") && (method == .get) && (parameters! as! [String : String] == ["cool" : "param"]) && ((encoding as! URLEncoding).destination == URLEncoding.default.destination) && (headers == nil)
                let request = MockDataRequest(session: session, requestTask: .data(nil, nil))
                
                return request
            }
        }
        
        let sessionManager = MockSessionManager()
        self.subject = AlamofireClient(baseUrl: "localhost", sessionManager: sessionManager)
        self.subject.sendRequest(url: "url", parameters: ["cool" : "param"], completion: { _ in })
        
        XCTAssertTrue(sessionManager.success)
    }
}
