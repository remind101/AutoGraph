import Foundation

fileprivate var AllStubs = [Stub]()

extension Array where Element == Stub {
    func find(_ request: URLRequest ) -> Data? {
        for stub in self {
            if stub.verify(request: request) {
                return stub.responseData
            }
        }
        return nil
    }
}

class Stub {
    static func clearAll() {
        AllStubs.removeAll()
    }
    
    var json: Any {
        return try! JSONSerialization.jsonObject(with: self.jsonData)
    }
    
    var jsonData: Data {
        precondition(self.jsonFixtureFile != nil, "Stub is missing jsonFixtureFile: \(self)")
        let path: String = {
            #if os(iOS)
            return Bundle(for: type(of: self)).path(forResource: self.jsonFixtureFile, ofType: "json")!
            
            #else
            let fileManager = FileManager.default
            let currentDirectoryPath = fileManager.currentDirectoryPath
            return "\(currentDirectoryPath)/AutoGraphTests/Data/\(self.jsonFixtureFile!).json"
            
            #endif
        }()
        print("loading stub at path: \(path)")
        return FileManager.default.contents(atPath: path)!
    }
    
    var graphQLQuery: String = ""
    var variables: [AnyHashable : Any]? = nil
    
    var httpMethod: String?
    var urlPath: String?
    var expectedResponseCode = 200
    var urlQueryString: String?
    var additionalHeaders = [String : Any]()
    var jsonFixtureFile: String?
    
    var responseData: Data? {
        let data = try! JSONSerialization.data(withJSONObject: self.json, options: JSONSerialization.WritingOptions(rawValue: 0))
        return data
    }
    
    let requestTime: TimeInterval = {
        return 0.01
    }()
    
    let responseTime: TimeInterval = {
        return 0.00
    }()
    
    func verify(request: URLRequest) -> Bool {
        if let httpMethod = self.httpMethod {
            if request.httpMethod != httpMethod {
                return false
            }
        }
        
        guard let url = request.url, url.relativePath == self.urlPath || url.absoluteString == self.urlPath else {
            return false
        }
        
        let body = request.httpBodyStream!.readfully()
        let jsonBody = try? JSONSerialization.jsonObject(with: body, options: JSONSerialization.ReadingOptions(rawValue: 0))
        let query = (jsonBody as! [String : Any])["query"] as! String
        guard query.condensedWhitespace == self.graphQLQuery.condensedWhitespace else {
            return false
        }
        
        if case let variables as NSDictionary = self.variables {
            guard case let otherVariables as NSDictionary = (jsonBody as! [AnyHashable : Any])["variables"] else {
                return false
            }
            
            guard otherVariables == variables else {
                return false
            }
        }
        
        if let urlQueryString = self.urlQueryString {
            if urlQueryString != url.query {
                return false
            }
        }
        
        return true
    }
    
    func registerStub() {
        AllStubs.append(self)
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

extension InputStream {
    func readfully() -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        
        self.open()
        defer { self.close() }
        
        var amount = 0
        repeat {
            amount = read(&buffer, maxLength: buffer.count)
            if amount > 0 {
                result.append(buffer, count: amount)
            }
        } while amount > 0
        
        return result
    }
}

class MockURLProtocol: URLProtocol {
    private let cannedHeaders = ["Content-Type" : "application/json; charset=utf-8"]
    
    // MARK: Properties
    private struct PropertyKeys {
        static let handledByForwarderURLProtocol = "HandledByProxyURLProtocol"
    }
    
    static func sessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        // Commented out Alamofire test stuff that we may want later.
        //        config.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        config.httpAdditionalHeaders = ["Session-Configuration-Header": "foo"]
        return config
    }
    
    static func session() -> URLSession {
        return Foundation.URLSession(configuration: self.sessionConfiguration())
    }
    
    // MARK: Class Request Methods
    override class func canInit(with request: URLRequest) -> Bool {
        return URLProtocol.property(forKey: PropertyKeys.handledByForwarderURLProtocol, in: request) == nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
        // Commented out Alamofire test stuff that we may want later.
//        guard let headers = request.allHTTPHeaderFields else { return request }
//        do {
//            return try URLEncoding.default.encode(request, with: headers)
//        } catch {
//            return request
//        }
    }
    
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return false
    }
    
    // MARK: Loading Methods
    override func startLoading() {
        defer { client?.urlProtocolDidFinishLoading(self) }
        let url = request.url!
        
        guard let data = AllStubs.find(request) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: cannedHeaders)!
            client?.urlProtocol(self,
                                didReceive: response,
                                cacheStoragePolicy: URLCache.StoragePolicy.notAllowed)
            let data = try! JSONSerialization.data(withJSONObject: ["status": 404, "description": "no stub for request: \(request)"], options: JSONSerialization.WritingOptions(rawValue: 0))
            client?.urlProtocol(self, didLoad: data)
            return
        }
        
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: cannedHeaders)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: URLCache.StoragePolicy.notAllowed)
        client?.urlProtocol(self, didLoad: data)
    }
    
    override func stopLoading() {
    }
}

// MARK: URLSessionDelegate extension
extension MockURLProtocol: URLSessionDelegate {
    func URLSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceiveData data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }
    
    func URLSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let response = task.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}
