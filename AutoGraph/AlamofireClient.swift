import Foundation
import Alamofire

public class AlamofireClient: Client {
    
    public let sessionManager: SessionManager
    public let baseUrl: String
    public var authHandler: AuthHandler {
        didSet {
            self.sessionManager.adapter = self.authHandler
            self.sessionManager.retrier = self.authHandler
        }
    }
    
    public var sessionConfiguration: URLSessionConfiguration {
        return self.sessionManager.session.configuration
    }
    
    public var tokens: AuthTokens {
        set {
            self.authHandler = AuthHandler(baseUrl: self.baseUrl,
                                           accessToken: newValue.accessToken,
                                           refreshToken: newValue.refreshToken)
        }
        get {
            return (accessToken: self.authHandler.accessToken,
                    refreshToken: self.authHandler.refreshToken)
        }
    }
    
    public required init(baseUrl: String,
                         accessToken: String? = nil,
                         refreshToken: String? = nil,
                         sessionManager: SessionManager = Alamofire.SessionManager.default) {
        
        self.sessionManager = sessionManager
        self.baseUrl = baseUrl
        self.authHandler = AuthHandler(baseUrl: baseUrl, accessToken: accessToken, refreshToken: refreshToken)
        
        self.sessionManager.adapter = self.authHandler
        self.sessionManager.retrier = self.authHandler
    }
    
    public func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ()) {
        self.sessionManager.request(url, parameters: parameters).responseJSON(completionHandler: completion)
    }
    
    public func cancelAll() {
        self.sessionManager.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }
}
