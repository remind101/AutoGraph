import Foundation
import Alamofire

public class AlamofireClient: Client {
    
    public let baseUrl: String
    public var authHandler: AuthHandler?
    
    public var tokens: (accessToken: String?, refreshToken: String?) {
        set {
            self.authHandler = AuthHandler(baseUrl: self.baseUrl,
                                           accessToken: newValue.accessToken,
                                           refreshToken: newValue.refreshToken)
        }
        get {
            return (accessToken: self.authHandler?.accessToken,
                    refreshToken: self.authHandler?.refreshToken)
        }
    }
    
    public init(baseUrl: String, accessToken: String? = nil, refreshToken: String? = nil) {
        self.baseUrl = baseUrl
        self.authHandler = AuthHandler(baseUrl: baseUrl, accessToken: accessToken, refreshToken: refreshToken)
        
        let sessionManager = Alamofire.SessionManager.default
        sessionManager.adapter = self.authHandler
        sessionManager.retrier = self.authHandler
    }
    
    public func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ()) {
        Alamofire.request(url, parameters: parameters).responseJSON(completionHandler: completion)
    }
    
    public func cancelAll() {
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }
}
