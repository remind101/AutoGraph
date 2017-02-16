import Foundation
import Alamofire

open class AlamofireClient: Client {
    
    public let sessionManager: SessionManager
    public let baseUrl: String
    public var httpHeaders: [String : String]
    public var authHandler: AuthHandler {
        didSet {
            self.sessionManager.adapter = self.authHandler
            self.sessionManager.retrier = self.authHandler
        }
    }
    
    public var sessionConfiguration: URLSessionConfiguration {
        return self.sessionManager.session.configuration
    }
    
    public var authTokens: AuthTokens {
        return (accessToken: self.authHandler.accessToken,
                refreshToken: self.authHandler.refreshToken)
    }
    
    public required init(baseUrl: String,
                         accessToken: String? = nil,
                         refreshToken: String? = nil,
                         httpHeaders: [String : String] = [:],
                         sessionManager: SessionManager = Alamofire.SessionManager.default) {
        
        self.baseUrl = baseUrl
        self.authHandler = AuthHandler(baseUrl: baseUrl, accessToken: accessToken, refreshToken: refreshToken)
        self.httpHeaders = httpHeaders
        self.sessionManager = sessionManager
        self.sessionManager.adapter = self.authHandler
        self.sessionManager.retrier = self.authHandler
    }
    
    public func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ()) {
        self.sessionManager.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: self.httpHeaders)
            .responseJSON(completionHandler: completion)
    }
    
    public func authenticate(authTokens: AuthTokens) {
        self.authHandler.reauthenticated(success: true, accessToken: authTokens.accessToken, refreshToken: authTokens.refreshToken)
    }
    
    public func cancelAll() {
        self.sessionManager.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }
}
