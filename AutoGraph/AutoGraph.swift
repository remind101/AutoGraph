import Alamofire
import Crust
import Foundation
import JSONValueRX

public protocol Cancellable {
    func cancelAll()
}

public typealias AuthTokens = (accessToken: String?, refreshToken: String?)

public protocol Client: RequestSender, Cancellable {
    var baseUrl: String { get }
    var authHandler: AuthHandler { get }
    var authTokens: AuthTokens { get }
    var sessionConfiguration: URLSessionConfiguration { get }
}

/// Declare a Mapped type as `ThreadUnsafe` if the object being mapped cannot be safely
/// passed between threads.
///
/// Before returning `Result` to the caller, a `ThreadUnsafe` object will be refetched
/// on the main thread using `primaryKey`.
public protocol ThreadUnsafe: class {
    static var primaryKeys: [String] { get }
    func value(forKeyPath keyPath: String) -> Any?
}

extension Int: AnyMappable { }
class VoidMapping: AnyMapping {
    typealias AdaptorKind = AnyAdaptorImp<MappedObject>
    typealias MappedObject = Int
    func mapping(tomap: inout Int, context: MappingContext) { }
}

// TODO: We should support non-equatable collections.
// TOOD: We should better apply currying and futures to clean some of this up.
public enum ResultBinding<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>
where C.Iterator.Element == CM.MappedObject, CM.MappedObject: Equatable {
    
    case object(mappingBinding: () -> Binding<M>, completion: RequestCompletion<M.MappedObject>)
    case collection(mappingBinding: () -> Binding<CM>, completion: RequestCompletion<C>)
}

public protocol LifeCycleRequest {
    associatedtype Result
}

open class LifeCycle<R: LifeCycleRequest> {
    open func willSend(request: R) throws { }
    open func didFinish(result: Result<R.Result>) throws { }
}

open class GlobalLifeCycle {
    open func willSend<R: Request>(request: R) throws { }
    open func didFinish<R: Request>(result: Result<R.Result>) throws { }
}

public protocol Request: LifeCycleRequest {
    /// The `Mapping` used to map from the returned JSON payload to a concrete type
    /// `Mapping.MappedObject`.
    associatedtype Mapping: Crust.Mapping
    
    /// The returned type for the request.
    /// E.g if the requests returns an array then change to `[Mapping.MappedObject]`.
    associatedtype Result = Mapping.MappedObject
    
    associatedtype Query: GraphQLQuery
    
    /// Hooks for the life cycle of the request.
    associatedtype T: LifeCycleRequest = Self
    var lifeCycle: LifeCycle<T>? { get }
    
    /// The query to be sent to GraphQL.
    var query: Query { get }
    
    /// The mapping to use when mapping JSON into the a concrete type.
    ///
    /// **WARNING:**
    ///
    /// `mapping` does NOT execute on the main thread. It's important that any `Adaptor`
    /// used by `mapping` establishes it's own connection to the DB from within `mapping`.
    ///
    /// Additionally, the mapped data (`Mapping.MappedObject`) is assumed to be safe to pass
    /// across threads unless it inherits from `ThreadUnsafe`. 
    var mapping: Binding<Mapping> { get }
}

public extension Request {
    var lifeCycle: LifeCycle<T>? {
        return nil
    }
}

extension Request
    where Result: RangeReplaceableCollection,
    Result.Iterator.Element == Mapping.MappedObject,
    Mapping.MappedObject: Equatable {
    
    func generateBinding(completion: @escaping RequestCompletion<Result>) -> ResultBinding<Mapping, Mapping, Result> {
        let didFinish = self.lifeCycle?.didFinish
        let lifeCycleCompletion: RequestCompletion<Result> = { result in
            do {
                try didFinish?(result.map { $0 as! Self.T.Result })
                completion(result)
            }
            catch let e {
                completion(.failure(e))
            }
        }
        
        return ResultBinding<Mapping, Mapping, Result>.collection(mappingBinding: { self.mapping }, completion: lifeCycleCompletion)
    }
}

extension Request where Result == Mapping.MappedObject {
    func generateBinding(completion: @escaping RequestCompletion<Mapping.MappedObject>) -> ResultBinding<Mapping, VoidMapping, Array<Int>> {
        let didFinish = self.lifeCycle?.didFinish
        let lifeCycleCompletion: RequestCompletion<Result> = { result in
            do {
                try didFinish?(result.map { $0 as! Self.T.Result })
                completion(result)
            }
            catch let e {
                completion(.failure(e))
            }
        }
        
        return ResultBinding<Mapping, VoidMapping, Array<Int>>.object(mappingBinding: { self.mapping }, completion: lifeCycleCompletion)
    }
}

public typealias RequestCompletion<R> = (_ result: Result<R>) -> ()

open class AutoGraph {
    public var baseUrl: String {
        get {
            return self.client.baseUrl
        }
    }
    
    public var authHandler: AuthHandler {
        get {
            return self.client.authHandler
        }
    }
    
    public let client: Client
    let dispatcher: Dispatcher
    
    private static let localHost = "http://localhost:8080/graphql"
    
    public required init(client: Client = AlamofireClient(baseUrl: localHost)) {
        self.client = client
        self.dispatcher = Dispatcher(url: client.baseUrl, requestSender: client, responseHandler: ResponseHandler())
        self.client.authHandler.delegate = self
    }
    
    internal convenience init() {
        let client = AlamofireClient(baseUrl: AutoGraph.localHost)
        let dispatcher = Dispatcher(url: client.baseUrl, requestSender: client, responseHandler: ResponseHandler())
        self.init(client: client, dispatcher: dispatcher)
    }
    
    internal init(client: Client, dispatcher: Dispatcher) {
        self.client = client
        self.dispatcher = dispatcher
        self.client.authHandler.delegate = self
    }
    
    public func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.Result>)
    where
    R.Result: RangeReplaceableCollection,
    R.Result.Iterator.Element == R.Mapping.MappedObject,
    R.Mapping.MappedObject: Equatable {
        
        self.dispatcher.send(request: request, resultBinding: request.generateBinding(completion: completion))
    }
    
    public func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.Result>)
    where R.Result == R.Mapping.MappedObject {
        self.dispatcher.send(request: request, resultBinding: request.generateBinding(completion: completion))
    }
    
    public func triggerReauthentication() {
        self.authHandler.reauthenticate()
    }
    
    public func cancelAll() {
        self.dispatcher.cancelAll()
        self.client.cancelAll()
    }
    
    open func reset() {
        self.cancelAll()
        self.dispatcher.paused = false
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
