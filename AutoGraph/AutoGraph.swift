import Foundation
import Alamofire

public protocol Cancellable {
    func cancelAll()
}

public typealias AuthTokens = (accessToken: String?, refreshToken: String?)

public protocol Client: RequestSender, Cancellable {
    var url: URL { get }
    var authHandler: AuthHandler? { get }
    var sessionConfiguration: URLSessionConfiguration { get }
}

public typealias RequestCompletion<SerializedObject> = (_ result: AutoGraphResult<SerializedObject>) -> ()

open class GlobalLifeCycle {
    open func willSend<R: Request>(request: R) throws { }
    open func didFinish<SerializedObject>(result: AutoGraphResult<SerializedObject>) throws { }
}

open class AutoGraph {
    public var url: URL {
        return self.client.url
    }
    
    public var authHandler: AuthHandler? {
        return self.client.authHandler
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
    public var webSocketClient: WebSocketClient?
    public let dispatcher: Dispatcher
    public var lifeCycle: GlobalLifeCycle?
    
    public static let localHost = "http://localhost:8080/graphql"
    
    public required init(
        client: Client,
        webSocketClient: WebSocketClient? = nil
    )
    {
        self.client = client
        self.webSocketClient = webSocketClient
        self.dispatcher = Dispatcher(requestSender: client, responseHandler: ResponseHandler())
        self.client.authHandler?.delegate = self
    }
    
    public init(client: Client, webSocketClient: WebSocketClient?, dispatcher: Dispatcher) {
        self.client = client
        self.webSocketClient = webSocketClient
        self.dispatcher = dispatcher
        self.client.authHandler?.delegate = self
    }
    
    // For Testing.
    internal convenience init() throws {
        guard let url = URL(string: AutoGraph.localHost) else {
            struct URLMissingError: Error {
                let urlString: String
            }
            throw URLMissingError(urlString: AutoGraph.localHost)
        }
        let client = AlamofireClient(url: url,
                                     session: Alamofire.Session(interceptor: AuthHandler()))
        let dispatcher = Dispatcher(requestSender: client, responseHandler: ResponseHandler())
        let webSocketClient = try WebSocketClient(url: URL(string: AutoGraph.localHost)!)
        self.init(client: client, webSocketClient: webSocketClient, dispatcher: dispatcher)
    }
    
    open func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.SerializedObject>) {
        let objectBindingPromise = { sendable in
            return request.generateBinding { [weak self] result in
                self?.complete(result: result, sendable: sendable, requestDidFinish: request.didFinish, completion: completion)
            }
        }
        
        let sendable = Sendable(dispatcher: self.dispatcher, request: request, objectBindingPromise: objectBindingPromise) { [weak self] request in
            try self?.lifeCycle?.willSend(request: request)
        }
        
        self.dispatcher.send(sendable: sendable)
    }
    
    open func send<R: Request>(includingNetworkResponse request: R, completion: @escaping (_ result: ResultIncludingNetworkResponse<R.SerializedObject>) -> ()) {
        let requestIncludingJSON = RequestIncludingNetworkResponse(request: request)
        self.send(requestIncludingJSON, completion: completion)
    }
    
    // TODO: Make it so you don't have to pass in operationName
    /// Subscribe to a subscription. Returns a handler to the Subscription which can be used to unsubscribe. A `nil` return value implies
    /// immediate failure, in which case, please check the error received in the completion block.
    ///
    /// It will form a websocket connection if one doesn't exist already.
    open func subscribe<R: Request>(_ request: R, operationName: String, completion: @escaping RequestCompletion<R.SerializedObject>) -> Subscriber? {
        guard let webSocketClient = self.webSocketClient else {
            completion(.failure(AutoGraphError.subscribeWithMissingWebSocketClient))
            return nil
        }
        
        do {
            let request = try SubscriptionRequest(request: request, operationName: operationName)
            let responseHandler = SubscriptionResponseHandler { (result) in
                switch result {
                case .success(let data):
                    self.webSocketClient?.subscriptionSerializer.serializeFinalObject(data: data, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            return webSocketClient.subscribe(request: request, responseHandler: responseHandler)
        }
        catch let error {
            completion(.failure(error))
            return nil
        }
    }
    
    open func unsubscribeAll<R: Request>(request: R, operationName: String) throws {
        let request = try SubscriptionRequest(request: request, operationName: operationName)
        try self.webSocketClient?.unsubscribeAll(request: request)
    }
    
    open func unsubscribe(subscriber: Subscriber) throws {
        try self.webSocketClient?.unsubscribe(subscriber: subscriber)
    }
    
    open func disconnectAndRetryWebSocket() {
        self.webSocketClient?.disconnect()
    }
    
    private func complete<SerializedObject>(result: AutoGraphResult<SerializedObject>, sendable: Sendable, requestDidFinish: (AutoGraphResult<SerializedObject>) throws -> (), completion: @escaping RequestCompletion<SerializedObject>) {
        
        do {
            try self.raiseAuthenticationError(from: result)
        }
        catch {
            self.triggerReauthentication()
            self.dispatcher.paused = true
            self.dispatcher.send(sendable: sendable)
            return
        }
        
        do {
            try requestDidFinish(result)
            try self.lifeCycle?.didFinish(result: result)
            completion(result)
        }
        catch let e {
            completion(.failure(e))
        }
    }
    
    private func raiseAuthenticationError<SerializedObject>(from result: AutoGraphResult<SerializedObject>) throws {
        guard
            case .failure(let error) = result,
            case let autoGraphError as AutoGraphError = error,
            case let .network(error: _, statusCode: code, response: _, underlying: _) = autoGraphError,
            code == Unauthorized401StatusCode
        else {
            return
        }
        
        throw error
    }
    
    public func triggerReauthentication() {
        self.authHandler?.reauthenticate()
    }
    
    public func cancelAll() {
        self.dispatcher.cancelAll()
        self.client.cancelAll()
    }
    
    open func reset() {
        self.cancelAll()
        self.dispatcher.paused = false
        self.webSocketClient?.disconnect()
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
