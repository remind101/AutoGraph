import Alamofire
import Crust
import Foundation
import JSONValueRX

public protocol Cancellable {
    func cancelAll()
}

public protocol Client: RequestSender, Cancellable {
    var baseUrl: String { get }
    var authHandler: AuthHandler? { get }
}

/// Declare a Mapped type as `ThreadUnsafe` if the object being mapped cannot be safely
/// passed between threads.
///
/// Before returning `Result` to the caller, a `ThreadUnsafe` object will be refetched
/// on the main thread using `primaryKey`.
public protocol ThreadUnsafe: class {
    static func primaryKey() -> String?
    func value(forKeyPath keyPath: String) -> Any?
}

public protocol Request {
    associatedtype Mapping: Crust.Mapping
    
    /// The query to be sent to GraphQL.
    var query: Operation { get }
    
    /// The mapping to use when mapping JSON into the a concrete type.
    ///
    /// **WARNING:**
    ///
    /// `mapping` does NOT execute on the main thread. It's important that any `Adaptor`
    /// used by `mapping` establishes it's own connection to the DB from within `mapping`.
    ///
    /// Additionally, the mapped data (`Mapping.MappedObject`) is assumed to be safe to pass
    /// across threads if no `primaryKeys` are provided by `mapping`. If `primaryKeys` are provided
    /// then the resulting mapped objects will be refetched upon returning to the main thread. 
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
    
    public func send<T: Request, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>
        (_ request: T, completion: @escaping RequestCompletion<T.Mapping>)
        where T.Mapping: ArrayMapping<SubType, SubAdaptor, SubMapping>,
        SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType, SubType: ThreadUnsafe {
    
            self.dispatcher.send(request: request, completion: completion)
    }
    
    public func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T.Mapping>) where T.Mapping.MappedObject: ThreadUnsafe {
        self.dispatcher.send(request: request, completion: completion)
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
