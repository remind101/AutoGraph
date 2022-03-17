import Foundation
import Alamofire

struct AutoGraphAlamofireClientError: LocalizedError {
    public var errorDescription: String? {
        return "Session of AlamofireClient must be initialized with `interceptor` of AuthHandler."
    }
}

open class AlamofireClient: Client {
    public let session: Session
    public let url: URL
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

    public required init(
        url: URL,
        httpHeaders: [String : String] = [:],
        session: Session)
    {
        self.url = url
        self.httpHeaders = httpHeaders
        self.session = session
    }
    
    public convenience init(
        url: String,
        httpHeaders: [String : String] = [:],
        session: Session)
        throws
    {
        self.init(url: try url.asURL(), httpHeaders: httpHeaders, session: session)
    }
    
    public func sendRequest(parameters: [String: Any]) async -> AFDataResponse<Any> {
        await withCheckedContinuation { continuation in
            self.session.request(
                self.url,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: HTTPHeaders(self.httpHeaders))
                .responseJSON(completionHandler: { response in
                    continuation.resume(returning: response)
                })
        }
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
