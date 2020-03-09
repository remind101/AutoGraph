import Foundation
import Alamofire

struct AutoGraphAlamofireClientError: LocalizedError {
    public var errorDescription: String? {
        return "Session of AlamofireClient must be initialized with `interceptor` of AuthHandler."
    }
}

open class AlamofireClient: Client {
    public let session: Session
    public let baseUrl: String
    public var httpHeaders: [String : String]
    public var authHandler: AuthHandler? {
        self.session.interceptor as? AuthHandler
    }
    public var requestInterceptor: RequestInterceptor? {
        self.session.interceptor
    }
    
    public var sessionConfiguration: URLSessionConfiguration {
        return self.session.session.configuration
    }

    public var authTokens: AuthTokens {
        return (accessToken: self.authHandler?.accessToken,
                refreshToken: self.authHandler?.refreshToken)
    }

    public required init(baseUrl: String,
                         httpHeaders: [String : String] = [:],
                         session: Session) {
        
        self.baseUrl = baseUrl
        self.httpHeaders = httpHeaders
        self.session = session
    }
    
    public func sendRequest(url: String, parameters: [String : Any], completion: @escaping (AFDataResponse<Any>) -> ()) {
        self.session.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: HTTPHeaders(self.httpHeaders))
            .responseJSON(completionHandler: completion)
    }

    public func authenticate(authTokens: AuthTokens) {
        self.authHandler?.reauthenticated(success: true, accessToken: authTokens.accessToken, refreshToken: authTokens.refreshToken)
    }
    
    public func cancelAll() {
        self.session.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }
}
