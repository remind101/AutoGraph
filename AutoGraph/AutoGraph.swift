import Foundation

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
    
    public func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.SerializedObject>)
    where
    R.SerializedObject: RangeReplaceableCollection,
    R.SerializedObject.Iterator.Element == R.Mapping.MappedObject,
    R.Mapping.MappedObject: Equatable {
        
        self.dispatcher.send(request: request, resultBinding: request.generateBinding(completion: completion))
    }
    
    public func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.SerializedObject>)
    where R.SerializedObject == R.Mapping.MappedObject {
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
