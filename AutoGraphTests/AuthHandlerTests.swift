import XCTest
import Alamofire
import Crust
import JSONValueRX
import Realm
@testable import AutoGraph

class AuthHandlerTests: XCTestCase {
    
    var subject: AuthHandler!
    
    override func setUp() {
        super.setUp()
        
        self.subject = AuthHandler(baseUrl: "", accessToken: "token", refreshToken: nil)
    }
    
    func testAdaptsAuthToken() {
        let urlRequest = try! self.subject.adapt(URLRequest(url: URL(string: "localhost")!))
        XCTAssertEqual(urlRequest.allHTTPHeaderFields!["Authorization"]!, "Bearer token")
    }
}
