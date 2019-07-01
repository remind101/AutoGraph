import XCTest
import Alamofire
import JSONValueRX
@testable import AutoGraphQL

class AuthHandlerTests: XCTestCase {
    
    var subject: AuthHandler!
    
    override func setUp() {
        super.setUp()
        
        self.subject = AuthHandler(baseUrl: "", accessToken: "token", refreshToken: "token")
    }
    
    override func tearDown() {
        self.subject = nil
        
        super.tearDown()
    }
    
    func testAdaptsAuthToken() {
        let urlRequest = try! self.subject.adapt(URLRequest(url: URL(string: "localhost")!))
        XCTAssertEqual(urlRequest.allHTTPHeaderFields!["Authorization"]!, "Bearer token")
    }
    
    func testGetsAuthTokensIfSuccess() {
        self.subject.reauthenticated(success: true, accessToken: "a", refreshToken: "b")
        XCTAssertEqual(self.subject.accessToken, "a")
        XCTAssertEqual(self.subject.refreshToken, "b")
    }
    
    func testDoesNotGetAuthTokensIfFailure() {
        XCTAssertNotNil(self.subject.accessToken)
        XCTAssertNotNil(self.subject.refreshToken)
        self.subject.reauthenticated(success: false, accessToken: "a", refreshToken: "b")
        XCTAssertNil(self.subject.accessToken)
        XCTAssertNil(self.subject.refreshToken)
    }
}
