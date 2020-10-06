import Foundation
import Starscream
import Alamofire

public typealias WebSocketConnected = (Result<Void, Error>) -> Void

public protocol WebSocketClientDelegate: class {
    func didReceive(event: WebSocketEvent)
    func didReceive(error: Error)
}

private let kAttemptReconnectCount = 3

/// The unique key for a subscription request. A combination of OperationName + variables.
public typealias SubscriptionID = String

public struct Subscriber: Hashable {
    let uuid = UUID()   // Disambiguates between multiple different subscribers of same subscription.
    let subscriptionID: SubscriptionID
    let serializableRequest: SubscriptionRequestSerializable    // Needed on reconnect.
    
    init(subscriptionID: String, serializableRequest: SubscriptionRequestSerializable) {
        self.subscriptionID = subscriptionID
        self.serializableRequest = serializableRequest
    }
    
    public static func == (lhs: Subscriber, rhs: Subscriber) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.uuid)
    }
}

open class WebSocketClient {
    public enum State {
        case connected
        case reconnecting
        case disconnected
    }
    
    // Reference type because it's used as a mutable dictionary within a dictionary.
    final class SubscriptionSet: Sequence {
        var set: [Subscriber : SubscriptionResponseHandler]
        
        init(set: [Subscriber : SubscriptionResponseHandler]) {
            self.set = set
        }
        
        func makeIterator() -> Dictionary<Subscriber, SubscriptionResponseHandler>.Iterator {
            return set.makeIterator()
        }
        
        func didChangeConnectionState(_ state: State) {
            self.set.forEach { (_, value: SubscriptionResponseHandler) in
                value.didChangeConnectionState(state)
            }
        }
    }
    
    public var webSocket: WebSocket
    public weak var delegate: WebSocketClientDelegate?
    public private(set) var state: State = .disconnected {
        didSet {
            self.subscriptions.forEach { $0.value.didChangeConnectionState(state) }
        }
    }
    
    public let subscriptionSerializer = SubscriptionResponseSerializer()
    internal var queuedSubscriptions = [Subscriber : WebSocketConnected]()
    internal var subscriptions = [SubscriptionID: SubscriptionSet]()
    internal var attemptReconnectCount = kAttemptReconnectCount
    
    public init(url: URL) throws {
        let request = try WebSocketClient.connectionRequest(url: url)
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
    
    public func setValue(_ value: String?, forHTTPHeaderField field: String) {
        self.webSocket.request.setValue(value, forHTTPHeaderField: field)
    }
    
    private var fullDisconnect = false
    public func disconnect() {
        self.fullDisconnect = true
        self.disconnectAndPossiblyReconnect(force: true)
    }
    
    public func disconnectAndPossiblyReconnect(force: Bool = false) {
        guard self.state != .disconnected, !force else {
            return
        }
        
        // TODO: Possible return something to the user if this fails?
        if let payload = try? GraphQLWSProtocol.connectionTerminate.serializedSubscriptionPayload() {
            self.write(payload)
        }
        
        self.webSocket.disconnect()
    }
    
    /// Subscribe to a Subscription, will automatically connect a websocket if it is not connected or disconnected.
    public func subscribe<R: Request>(request: SubscriptionRequest<R>, responseHandler: SubscriptionResponseHandler) -> Subscriber {
        // If we already have a subscription for that key then just add the subscriber to the set for that key with a callback.
        // Otherwise if connected send subscription and add to subscriber set.
        // Otherwise queue it and it will be added after connecting.
        
        let subscriber = Subscriber(subscriptionID: request.subscriptionID, serializableRequest: request)
        let connectionCompletionBlock: WebSocketConnected = self.connectionCompletionBlock(subscriber: subscriber, responseHandler: responseHandler)
        
        guard self.state != .connected else {
            connectionCompletionBlock(.success(()))
            return subscriber
        }
        
        self.queuedSubscriptions[subscriber] = connectionCompletionBlock
        self.webSocket.connect()
        return subscriber
    }
    
    func connectionCompletionBlock(subscriber: Subscriber, responseHandler: SubscriptionResponseHandler) -> WebSocketConnected {
        return { [weak self] (result) in
            guard let self = self else { return }
            
            // If we already have a subscription for that key then just add the subscriber to the set for that key with a callback.
            // Otherwise if connected send subscription and add to subscriber set.
            
            if let subscriptionSet = self.subscriptions[subscriber.subscriptionID] {
                subscriptionSet.set[subscriber] = responseHandler
            }
            else {
                self.subscriptions[subscriber.subscriptionID] = SubscriptionSet(set: [subscriber : responseHandler])
                do {
                    try self.sendSubscription(request: subscriber.serializableRequest)
                }
                catch let e {
                    responseHandler.didReceive(error: e)
                }
            }
        }
    }
    
    public func unsubscribeAll<R: Request>(request: SubscriptionRequest<R>) throws {
        let id = request.subscriptionID
        self.queuedSubscriptions = self.queuedSubscriptions.filter { (key, _) -> Bool in
            return key.subscriptionID == id
        }
        
        if let subscriber = self.subscriptions.removeValue(forKey: id)?.set.first?.key {
            try self.unsubscribe(subscriber: subscriber)
        }
    }
    
    public func unsubscribe(subscriber: Subscriber) throws {
        // Write the unsubscribe, and only remove our subscriptions for that subscriber.
        self.queuedSubscriptions.removeValue(forKey: subscriber)
        self.subscriptions.removeValue(forKey: subscriber.subscriptionID)
        
        let stopPayload = try GraphQLWSProtocol.stop.serializedSubscriptionPayload(id: subscriber.subscriptionID)
        self.write(stopPayload)
    }
    
    func write(_ message: String) {
        self.webSocket.write(string: message, completion: nil)
    }
    
    func sendSubscription(request: SubscriptionRequestSerializable) throws {
        let subscriptionPayload = try request.serializedSubscriptionPayload()
        guard self.state == .connected else {
            throw WebSocketError.webSocketNotConnected(subscriptionPayload: subscriptionPayload)
        }
        self.write(subscriptionPayload)
    }
    
    private var reconnecting = false
    /// Attempts to reconnect and re-subscribe with multiplied backoff up to 30 seconds. Returns the delay.
    func reconnect() -> DispatchTimeInterval? {
        guard !self.reconnecting, !self.fullDisconnect else { return nil }
        if self.attemptReconnectCount > 0 {
            self.attemptReconnectCount -= 1
        }
        self.reconnecting = true
        self.state = .reconnecting
        
        let delayInSeconds = DispatchTimeInterval.seconds(min(abs(kAttemptReconnectCount - self.attemptReconnectCount) * 10, 30))
        DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) { [weak self] in
            guard let self = self else { return }
            // Requeue all so they don't get error callbacks on disconnect and they get re-subscribed on connect.
            self.requeueAllSubscribers()
            self.disconnectAndPossiblyReconnect()
            self.webSocket.connect()
        }
        return delayInSeconds
    }
    
    /// Takes all subscriptions and puts them back on the queue, used for reconnection.
    func requeueAllSubscribers() {
        for (_, subscriptionSet) in self.subscriptions {
            for (subscriber, subscriptionResponseHandler) in subscriptionSet {
                self.queuedSubscriptions[subscriber] = connectionCompletionBlock(subscriber: subscriber, responseHandler: subscriptionResponseHandler)
            }
        }
        self.subscriptions.removeAll(keepingCapacity: true)
    }
    
    // TODO: test
    /// Take all connection completion blocks out of the queue and runs them. Removes from queue first to avoid any side affects.
    func didConnect() throws {
        self.state = .connected
        self.attemptReconnectCount = kAttemptReconnectCount
        self.reconnecting = false
        
        let connectedPayload = try GraphQLWSProtocol.connectionInit.serializedSubscriptionPayload()
        self.write(connectedPayload)
        
        let queuedSubscriptions = self.queuedSubscriptions
        self.queuedSubscriptions.removeAll()
        queuedSubscriptions.forEach { (_, connected: WebSocketConnected) in
            connected(.success(()))
        }
    }
    
    func reset() {
        self.disconnect()
        self.subscriptions.removeAll()
        self.queuedSubscriptions.removeAll()
        self.attemptReconnectCount = kAttemptReconnectCount
        self.reconnecting = false
    }
}

// MARK: - Class Method

extension WebSocketClient {
    class func connectionRequest(url: URL) throws -> URLRequest {
        var defaultHeders = [String: String]()
        defaultHeders["Sec-WebSocket-Protocol"] = "graphql-ws"
        defaultHeders["Origin"] = url.absoluteString
        
        return try URLRequest(url: url, method: .get, headers: HTTPHeaders(defaultHeders))
    }
}

// MARK: - WebSocketDelegate

extension WebSocketClient: WebSocketDelegate {
    // This is called on the Starscream callback queue, which defaults to Main.
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        self.delegate?.didReceive(event: event)
        
        // If we get any event at all just assume that the previous reconnect attempt either succeeded or failed for simplicity.
        self.reconnecting = false
        
        do {
            switch event {
            case .disconnected:
                self.state = .disconnected
                if !self.fullDisconnect {
                    _ = self.reconnect()
                }
                self.fullDisconnect = false
            case .cancelled:
                _ = self.reconnect()
            case .binary(let data):
                let subscriptionResponse = try self.subscriptionSerializer.serialize(data: data)
                self.didReceive(subscriptionResponse: subscriptionResponse)
            case let .text(text):
                let subscriptionResponse = try self.subscriptionSerializer.serialize(text: text)
                self.didReceive(subscriptionResponse: subscriptionResponse)
            case .connected:
                try self.didConnect()
            case let .reconnectSuggested(shouldReconnect):
                if shouldReconnect {
                    _ = self.reconnect()
                }
            case .viabilityChanged: //let .viabilityChanged(isViable):
                // TODO: if `isViable` is false then we need to pause sending and wait for x seconds for it to return.
                // if it doesn't return to `isViable` true then reconnect.
                break
            case let .error(error):
                if let error = error {
                    self.delegate?.didReceive(error: error)
                }
                _ = self.reconnect()
            case .ping, .pong:  // We just ignore these for now.
                break
            }
        }
        catch let error {
            self.delegate?.didReceive(error: error)
        }
    }
    
    func didReceive(subscriptionResponse: SubscriptionResponse) {
        let id = subscriptionResponse.id
        guard let subscriptionSet = self.subscriptions[id] else {
            print("WARNING: Recieved a subscription response for a subscription that AutoGraph is no longer subscribed to. SubscriptionID: \(subscriptionResponse.id)")
            return
        }
        subscriptionSet.forEach { (_, value: SubscriptionResponseHandler) in
            value.didReceive(subscriptionResponse: subscriptionResponse)
        }
    }
}
