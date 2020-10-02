import Foundation
import Starscream
import Alamofire

public typealias WebSocketConnected = (Result<Bool, Error>) -> Void

public protocol WebSocketClientDelegate {
    func didReceive(event: WebSocketEvent)
    func didReceive(error: Error)
}

public typealias GraphQLMap = [String: Any]
private let kAttemptReconnectCount = 3

open class WebSocketClient {
    public enum State {
        case connected
        case disconnected
    }
    
    let queue: DispatchQueue
    public var webSocket: WebSocket
    public var delegate: WebSocketClientDelegate?
    public var state: State = .disconnected
    
    private var subscriptionSerializer = SubscriptionSerializer()
    private var subscribers = [String: SubscriptionResponseHandler]()
    private var subscriptions : [String: String] = [:]
    private var attemptReconnectCount = kAttemptReconnectCount
    private var connectionCompletionBlock: WebSocketConnected?
    
    public init(url: URL,
                queue: DispatchQueue = DispatchQueue(label:  "com.autograph.WebSocketClient", qos: .default)) throws {
        self.queue = queue
        guard let request = try WebSocketClient.subscriptionRequest(url: url) else {
            throw WebSocketError.requestCreationFailed(url)
        }
        
        self.webSocket = WebSocket(request: request)
        self.webSocket.delegate = self
    }
    
    deinit {
        self.webSocket.forceDisconnect()
        self.webSocket.delegate = nil
    }
    
    public func authenticate(token: String?, headers: [String: String]?) {
        var headers = headers ?? [:]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        headers.forEach { (key, value) in
            self.webSocket.request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    public func connect(completion: WebSocketConnected?) {
        guard self.state != .connected else {
            completion?(.success(true))
            return
        }
        
        self.connectionCompletionBlock = completion
        self.webSocket.connect()
    }
    
    public func disconnect() {
        guard self.state != .disconnected else {
            return
        }
        
        self.queue.async {
            if let message = GraphQLWSProtocol(type: .connectionTerminate).rawMessage {
                self.write(message)
            }
            
            self.webSocket.disconnect()
        }
    }
    
    public func subscribe<R: Request>(request: SubscriptionRequest<R>, responseHandler: SubscriptionResponseHandler) {
        self.connect { (result) in
            switch result {
            case let .success(isConnected):
                if isConnected {
                    self.sendSubscription(request: request, responseHandler: responseHandler)
                }
                else {
                    guard self.attemptReconnectCount > 0 else {
                        responseHandler.didFinish(error: WebSocketError.webSocketNotConnected(request.id))
                        return
                    }
                    
                    self.attemptReconnectCount -= 1
                    self.subscribe(request: request, responseHandler: responseHandler)
                }
            case let .failure(error):
                responseHandler.didFinish(error: error)
            }
        }
    }
    
    public func unsubscribe<R: Request>(request: SubscriptionRequest<R>) {
        if let message = GraphQLWSProtocol(id: request.id, type: .stop).rawMessage {
            self.write(message)
        }
        self.subscribers.removeValue(forKey: request.id)
        self.subscriptions.removeValue(forKey: request.id)
    }
    
    func write(_ message: String) {
        self.webSocket.write(string: message, completion: nil)
    }
    
    func sendSubscription<R: Request>(request: SubscriptionRequest<R>, responseHandler: SubscriptionResponseHandler) {
        do {
            let subscriptionMessage = try request.subscriptionMessage()
            
            guard self.state == .connected else {
                responseHandler.didFinish(error: WebSocketError.webSocketNotConnected(subscriptionMessage))
                return
            }
            
            self.queue.async {
                self.subscribers[request.id] = responseHandler
                self.subscriptions[request.id] = subscriptionMessage
                self.write(subscriptionMessage)
            }
        }
        catch let error {
            responseHandler.didFinish(error: error)
        }
    }
}

// MARK: - Class Method

extension WebSocketClient {
    class func subscriptionRequest(url: URL) throws -> URLRequest? {
        var defaultHeders = [String: String]()
        defaultHeders["Sec-WebSocket-Protocol"] = "graphql-ws"
        defaultHeders["Origin"] = url.absoluteString
        
        return try URLRequest(url: url, method: .get, headers: HTTPHeaders(defaultHeders))
    }
}

// MARK: - WebSocketDelegate
extension WebSocketClient: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        DispatchQueue.main.async {
            self.delegate?.didReceive(event: event)
        }
        
        do {
            switch event {
            case .disconnected:
                self.reset()
            case .binary(let data):
                let subscription = try self.subscriptionSerializer.serialize(data: data)
                self.didReceive(subscription: subscription)
            case let .text(text):
                let subscription = try self.subscriptionSerializer.serialize(text: text)
                self.didReceive(subscription: subscription)
            case .connected:
                self.connectionInitiated()
                if self.state == .connected {
                    self.queue.async {
                        self.subscriptions.forEach { (_, value) in
                            self.write(value)
                        }
                    }
                }
                
                self.state = .connected
                self.sendConnectionCompletionBlock(isSuccessful: true)
            case let .reconnectSuggested(shouldReconnect):
                if shouldReconnect {
                    self.reconnectWebSocket()
                }
            case let .error(error):
                self.sendConnectionCompletionBlock(isSuccessful: false, error: error)
            case .cancelled,
                 .ping,
                 .pong,
                 .viabilityChanged:
                break
            }
        }
        catch let error {
            DispatchQueue.main.async {
                self.delegate?.didReceive(error: error)
            }
        }
    }
}

// MARK: - Connection Helper Methods

extension WebSocketClient {
    func connectionInitiated() {
        if let message = GraphQLWSProtocol(type: .connectionInit).rawMessage {
            self.write(message)
        }
    }
    
    func reconnectWebSocket() {
        guard self.attemptReconnectCount > 0 else {
            self.disconnect()
            return
        }
        
        self.attemptReconnectCount -= 1
        self.disconnect()
        self.webSocket.connect()
    }
    
    func sendConnectionCompletionBlock(isSuccessful: Bool, error: Error? = nil) {
        guard let completion = self.connectionCompletionBlock else {
            return
        }
        
        if let error = error {
            completion(.failure(error))
        }
        else {
            completion(.success(isSuccessful))
        }
        
        self.connectionCompletionBlock = nil
    }
    
    func reset() {
        self.subscriptions.removeAll()
        self.subscribers.removeAll()
        self.attemptReconnectCount = kAttemptReconnectCount
        self.sendConnectionCompletionBlock(isSuccessful: false)
    }
    
    func didReceive(subscription: SubscriptionResponsePayload) {
        guard let id = subscription.id else {
            return
        }
        
        self.subscribers[id]?.didFinish(subscription: subscription)
    }
}
