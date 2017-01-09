import Alamofire
import Foundation

public typealias RefreshCompletion = (_ succeeded: Bool, _ accessToken: String?, _ refreshToken: String?) -> Void

internal protocol AuthHandlerDelegate: class {
    func authHandlerBeganReauthentication(_ authHandler: AuthHandler)
    func authHandler(_ authHandler: AuthHandler, reauthenticatedSuccessfully: Bool)
}

public protocol ReauthenticationDelegate: class {
    func autoGraphRequiresReauthentication(accessToken: String?, refreshToken: String?, completion: RefreshCompletion)
}

// NOTE: Currently too coupled to Alamofire, will need to write an adaptor and
// move some of this into AlamofireClient eventually.

public class AuthHandler {
    
    internal weak var delegate: AuthHandlerDelegate?
    public weak var reauthenticationDelegate: ReauthenticationDelegate?
    
    fileprivate let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        
        return SessionManager(configuration: configuration)
    }()
    
    public let baseUrl: String
    public fileprivate(set) var accessToken: String?
    public fileprivate(set) var refreshToken: String?
    
    public fileprivate(set) var isRefreshing = false
    
    fileprivate let lock = NSLock()
    fileprivate let callbackQueue: DispatchQueue
    fileprivate var requestsToRetry: [RequestRetryCompletion] = []
    
    public init(baseUrl: String, accessToken: String?, refreshToken: String?, callbackQueue: DispatchQueue = DispatchQueue.main) {
        self.baseUrl = baseUrl
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.callbackQueue = callbackQueue
    }
}

// MARK: - RequestAdapter

extension AuthHandler: RequestAdapter {
    
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        
        if let url = urlRequest.url, let accessToken = self.accessToken, url.absoluteString.hasPrefix(baseUrl) {
            var urlRequest = urlRequest
            urlRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
            return urlRequest
        }
        
        return urlRequest
    }
}

// MARK: - RequestRetrier

extension AuthHandler: RequestRetrier {
    
    public func should(_ manager: SessionManager, retry request: Alamofire.Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        
        guard request.retryCount == 0 else {
            completion(false, 0.0)
            return
        }
        
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 else {
            completion(false, 0.0)
            return
        }
        
        self.requestsToRetry.append(completion)
        
        guard !self.isRefreshing else {
            return
        }
        
        self.isRefreshing = true
        
        self.callbackQueue.async {
            self.delegate?.authHandlerBeganReauthentication(self)
            
            self.reauthenticationDelegate?.autoGraphRequiresReauthentication(accessToken: self.accessToken, refreshToken: self.refreshToken) {
                [weak self] succeeded, accessToken, refreshToken in
                
                guard let strongSelf = self else { return }
                
                strongSelf.lock.lock()
                defer {
                    strongSelf.lock.unlock()
                }
                
                if let accessToken = accessToken, let refreshToken = refreshToken {
                    strongSelf.accessToken = accessToken
                    strongSelf.refreshToken = refreshToken
                }
                
                strongSelf.requestsToRetry.forEach { $0(succeeded, 0.0) }
                strongSelf.requestsToRetry.removeAll()
                
                strongSelf.isRefreshing = false
                strongSelf.delegate?.authHandler(strongSelf, reauthenticatedSuccessfully: succeeded)
            }
        }
    }
}
