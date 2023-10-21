import Alamofire
import Foundation

public typealias ReauthenticationRefreshCompletion = (_ succeeded: Bool, _ accessToken: String?, _ refreshToken: String?) -> Void

internal protocol AuthHandlerDelegate: AnyObject {
    func authHandlerBeganReauthentication(_ authHandler: AuthHandler)
    func authHandler(_ authHandler: AuthHandler, reauthenticatedSuccessfully: Bool)
}

public protocol ReauthenticationDelegate: AnyObject {
    func autoGraphRequiresReauthentication(accessToken: String?, refreshToken: String?, completion: ReauthenticationRefreshCompletion)
}

public let Unauthorized401StatusCode = 401

// NOTE: Currently too coupled to Alamofire, will need to write an adapter and
// move some of this into AlamofireClient eventually.

public class AuthHandler: RequestInterceptor {
    private typealias RequestRetryCompletion = (RetryResult) -> Void
    
    internal weak var delegate: AuthHandlerDelegate?
    public weak var reauthenticationDelegate: ReauthenticationDelegate?
    
    public fileprivate(set) var accessToken: String?
    public fileprivate(set) var refreshToken: String?
    public fileprivate(set) var isRefreshing = false
    
    private let lock = NSRecursiveLock()
    private var requestsToRetry: [RequestRetryCompletion] = []
    
    public init(accessToken: String? = nil, refreshToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

// MARK: - RequestAdapter

extension AuthHandler: RequestAdapter {
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void)
    {
        self.lock.lock()
        
        var urlRequest = urlRequest
        if let accessToken = self.accessToken {
            urlRequest.headers.add(.authorization(bearerToken: accessToken))
        }
        
        self.lock.unlock()
        completion(.success(urlRequest))
    }
}

// MARK: - RequestRetrier

extension AuthHandler: RequestRetrier {
    public func retry(
        _ request: Alamofire.Request,
        for session: Session, dueTo error: Error,
        completion: @escaping (RetryResult) -> Void)
    {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        
        // Don't retry if we already failed once.
        guard request.retryCount == 0 else {
            completion(.doNotRetry)
            return
        }
        
        // Retry unless it's a 401, in which case, rauth.
        guard
            case let response as HTTPURLResponse = request.task?.response,
            response.statusCode == Unauthorized401StatusCode
        else {
            completion(.retry)
            return
        }
        
        self.requestsToRetry.append(completion)
        
        self.reauthenticate()
    }
    
    func reauthenticate() {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        
        guard !self.isRefreshing else {
            return
        }
        
        self.isRefreshing = true
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.delegate?.authHandlerBeganReauthentication(strongSelf)
            
            strongSelf.reauthenticationDelegate?.autoGraphRequiresReauthentication(
                accessToken: strongSelf.accessToken,
                refreshToken: strongSelf.refreshToken)
            { [weak self] succeeded, accessToken, refreshToken in
                
                self?.reauthenticated(success: succeeded, accessToken: accessToken, refreshToken: refreshToken)
            }
        }
    }
    
    public func reauthenticated(success: Bool, accessToken: String?, refreshToken: String?) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        
        if success {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.requestsToRetry.forEach { $0(.retry) }
        }
        else {
            self.accessToken = nil
            self.refreshToken = nil
        }
        
        self.requestsToRetry.removeAll()
        
        guard self.isRefreshing else {
            return
        }
        
        self.isRefreshing = false
        self.delegate?.authHandler(self, reauthenticatedSuccessfully: success)
    }
}
