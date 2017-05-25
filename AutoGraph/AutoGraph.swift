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

public typealias RequestCompletion<SerializedObject> = (_ result: Result<SerializedObject>) -> ()

open class GlobalLifeCycle {
    open func willSend<R: Request>(request: R) throws { }
    open func didFinish<SerializedObject>(result: Result<SerializedObject>) throws { }
}

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
    
    public var networkErrorParser: NetworkErrorParser? {
        get {
            return self.dispatcher.responseHandler.networkErrorParser
        }
        set {
            self.dispatcher.responseHandler.networkErrorParser = newValue
        }
    }
    
    public let client: Client
    public let dispatcher: Dispatcher
    public var lifeCycle: GlobalLifeCycle?
    
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
        
        let objectBinding = request.generateBinding { [weak self] result in
            do {
                try request.didFinish(result: result)
                try self?.lifeCycle?.didFinish(result: result)
                completion(result)
            }
            catch let e {
                completion(.failure(e))
            }
        }
        
        self.dispatcher.send(request: request, objectBinding: objectBinding) { [weak self] request in
            try self?.lifeCycle?.willSend(request: request)
        }
    }
    
    public func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.SerializedObject>)
    where R.SerializedObject == R.Mapping.MappedObject {
        
        let objectBinding = request.generateBinding { [weak self] result in
            do {
                try request.didFinish(result: result)
                try self?.lifeCycle?.didFinish(result: result)
                completion(result)
            }
            catch let e {
                completion(.failure(e))
            }
        }
        
        self.dispatcher.send(request: request, objectBinding: objectBinding) { [weak self] request in
            try self?.lifeCycle?.willSend(request: request)
        }
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
