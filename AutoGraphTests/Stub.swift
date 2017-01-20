import Foundation
import OHHTTPStubs

class Stub {
    var json: Any? {
        if let jsonFixtureFile = self.jsonFixtureFile {
            let path = Bundle(for: type(of: self)).path(forResource: jsonFixtureFile, ofType: "json")!
            if let jsonData = NSData(contentsOfFile: path) {
                if let jsonResult = try? JSONSerialization.jsonObject(with: jsonData as Data, options: JSONSerialization.ReadingOptions(rawValue: UInt(0))) {
                    return jsonResult
                }
            }
        }
        
        return nil
    }
    
    var graphQLQuery: String = ""
    
    var httpMethod: String?
    var urlPath: String?
    var expectedResponseCode = 200
    var urlQueryString: String?
    var additionalHeaders = [String : Any]()
    var jsonFixtureFile: String?
    
    var responseData: Data? {
        let data = try! JSONSerialization.data(withJSONObject: self.json!, options: JSONSerialization.WritingOptions(rawValue: 0))
        return data
    }
    
    let requestTime: TimeInterval = {
        return 0.01
    }()
    
    let responseTime: TimeInterval = {
        return 0.00
    }()
    
    var responseObject: OHHTTPStubsResponse {
        let response = OHHTTPStubsResponse(data: self.responseData!, statusCode: Int32(self.expectedResponseCode), headers: self.responseHeaders)
        
        return response.requestTime(self.requestTime, responseTime: self.responseTime)
    }
    
    func registerStub() {
        
        func verify(request: URLRequest) -> Bool {
            if let httpMethod = self.httpMethod {
                if request.httpMethod != httpMethod {
                    return false
                }
            }
            
            guard let url = request.url, url.relativePath == self.urlPath || url.absoluteString == self.urlPath else {
                return false
            }
            
            let queryItems = URLComponents(string: url.absoluteString)?.queryItems
            let query = queryItems?.filter({ $0.name == "query" }).first
            guard query?.value?.condensedWhitespace == self.graphQLQuery.condensedWhitespace else {
                    return false
            }
            
            if let urlQueryString = self.urlQueryString {
                if urlQueryString != url.query {
                    return false
                }
            }
            
            return true
        }
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            
            return verify(request: request)
            
        }, withStubResponse: { request in
            let response = self.responseObject
            
            return response;
        })
    }
    
    var responseHeaders: [String : Any] {
        var defaultHeaders: [String : Any] = [
            "Cache-Control" : "max-age=0, private, must-revalidate",
            "Content-Type" : "application/json"
        ]
        self.additionalHeaders.forEach { key, value in defaultHeaders[key] = value }
        
        return defaultHeaders
    }
    
}

extension String {
    var condensedWhitespace: String {
        let components = self.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
