import Alamofire
import Crust
import Foundation
import JSONValueRX

public protocol Client: RequestSender, Cancellable {
    var baseUrl: String { get }
    var authHandler: AuthHandler? { get }
}

public protocol Cancellable {
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
            return self.client.baseUrl
        }
    }
    
    public var authHandler: AuthHandler? {
        get {
            return self.client.authHandler
        }
    }
    
    let client: Client
    let dispatcher: Dispatcher
    
    private static let localHost = "http://localhost:8080/graphql"
    
    public required init(client: Client = AlamofireClient(baseUrl: localHost)) {
        self.client = client
        self.dispatcher = Dispatcher(url: client.baseUrl, requestSender: client, responseHandler: ResponseHandler())
        self.client.authHandler?.delegate = self
    }
    
    convenience init() {
        let client = AlamofireClient(baseUrl: AutoGraph.localHost)
        let dispatcher = Dispatcher(url: client.baseUrl, requestSender: client, responseHandler: ResponseHandler())
        self.init(client: client, dispatcher: dispatcher)
    }
    
    init(client: Client, dispatcher: Dispatcher) {
        self.client = client
        self.dispatcher = dispatcher
        self.client.authHandler?.delegate = self
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
