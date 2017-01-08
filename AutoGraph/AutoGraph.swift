import Alamofire
import Crust
import Foundation
import JSONValueRX

typealias Client = RequestSender & Cancellable

protocol Cancellable {
    func cancelAll()
}

public protocol Request {
    associatedtype Mapping: Crust.Mapping
    
    var query: Operation { get }
    var mapping: Mapping { get }
}

public typealias RequestCompletion<M: Crust.Mapping> = (_ result: Result<M.MappedObject>) -> ()

public class AutoGraph {
    public var baseUrl: String {
        get {
            return self.dispatcher.url
        }
        set {
            self.dispatcher.url = newValue
            self.authHandler = AuthHandler(baseUrl: newValue,
                                           accessToken: self.authHandler.accessToken,
                                           refreshToken: self.authHandler.refreshToken)
        }
    }
    
    public var authHandler: AuthHandler {
        didSet {
            self.authHandler.delegate = self
        }
    }
    
    let client: Client
    let dispatcher: Dispatcher
    
    convenience init(baseUrl: String = "http://localhost:8080/graphql") {
        let client = AlamofireClient()
        let dispatcher = Dispatcher(url: baseUrl, requestSender: client, responseHandler: ResponseHandler())
        self.init(baseUrl: baseUrl, client: client, dispatcher: dispatcher)
    }
    
    init(baseUrl: String = "http://localhost:8080/graphql", client: Client, dispatcher: Dispatcher) {
        self.client = client
        self.dispatcher = dispatcher
        self.authHandler = AuthHandler(baseUrl: baseUrl, accessToken: nil, refreshToken: nil)
        self.authHandler.delegate = self
    }
    
    public func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T.Mapping>) {
        self.dispatcher.send(request: request, completion: completion)
    }
    
    public func cancelAll() {
        self.dispatcher.cancelAll()
        self.client.cancelAll()
    }
}

extension AutoGraph: AuthHandlerDelegate {
    func authHandlerBeganReauthentication(_ authHandler: AuthHandler) {
        self.dispatcher.paused = true
    }
    
    func authHandler(_ authHandler: AuthHandler, reauthenticatedSuccessfully: Bool) {
        guard reauthenticatedSuccessfully else {
            self.cancelAll()
            return
        }
        
        self.dispatcher.paused = false
    }
}
