import Foundation
import Starscream
import Alamofire

public typealias SerializedObject = Decodable
public typealias WebSocketCompletionBlock = (Result<Data, Error>) -> Void

public protocol WebSocketClientDelegate {
    func didReceive(event: WebSocketEvent)
    func webSocketDidConnect(headers: [String : String])
}

public typealias GraphQLMap = [String: Any]
private let kAttemptReconnectCount = 3

open class WebSocketClient {
    public enum State {
        case connected
        case disconnected
    }
    
    public enum WebSocketError: Error {
        case createRequestFailed(String)
        case webSocketNotConnected(String)
        case subscriptionRequestBodyFailed(String)
        case messagePayloadFailed(GraphQLMap)
        
        public var localizedDescription: String {
            switch self {
            case let .createRequestFailed(url):
                return "URLRequest for url: \(url) creation failed for websocket"
            case let .webSocketNotConnected(subscription):
                return "WebSocket is not open to make subscription: \(subscription)"
            case let .subscriptionRequestBodyFailed(operationName):
                return "Subscription request body failed to serialize for query: \(operationName)"
            case let .messagePayloadFailed(playload):
                return "Subscription message payload failed to serialize message string: \(playload)"
            }
        }
    }
    
    let queue: DispatchQueue
    public let webSocket: WebSocket
    public var delegate: WebSocketClientDelegate?
    public var state: State = .disconnected
    public var request: URLRequest {
        self.webSocket.request
    }
    
    private var subscribers = [String: WebSocketCompletionBlock]()
    private var subscriptions : [String: String] = [:]
    private var attemptReconnectCount = kAttemptReconnectCount
    
    public init?(baseUrl: String,
                 queue: DispatchQueue = DispatchQueue(label:  "com.autograph.WebSocketClient", qos: .background)) throws {
        self.queue = queue
        guard let request = try WebSocketClient.createRequest(baseUrl: baseUrl) else {
            throw WebSocketError.createRequestFailed(baseUrl)
        }
        
        self.webSocket = WebSocket(request: request)
        self.webSocket.delegate = self
    }
    
    public func connect(token: String?, headers: [String: String]?) {
        var headers = headers ?? [:]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        headers.forEach { (key, value) in
            self.webSocket.request.setValue(value, forHTTPHeaderField: key)
        }
        self.webSocket.connect()
        
    }
    
    public func disconnect() {
        guard self.state != .disconnected else {
            return
        }
        
        self.queue.async {
            if let message = OperationMessage(type: .connectionTerminate).rawMessage {
                self.write(message)
            }
            
            self.webSocket.disconnect()
            self.subscriptions.removeAll()
            self.subscribers.removeAll()
            self.state = .disconnected
            self.attemptReconnectCount = kAttemptReconnectCount
        }
    }
    
    public func subscribe<R: Request>(_ request: R, operationName: String, completion: @escaping WebSocketCompletionBlock) {
        do {
            guard let body = try self.requestBody(request, operationName: operationName) else {
                completion(.failure(WebSocketError.subscriptionRequestBodyFailed(operationName)))
                return
            }
            
            guard let message = OperationMessage(payload: body, id: operationName).rawMessage else {
                completion(.failure(WebSocketError.messagePayloadFailed(body)))
                return
            }
            
            guard self.state == .connected else {
                completion(.failure(WebSocketError.webSocketNotConnected(message)))
                return
            }
            
            self.queue.async {
                self.subscribers[operationName] = completion
                self.subscriptions[operationName] = message
                self.write(message)
            }
        }
        catch let error {
            completion(.failure(error))
        }
    }
    
    public func unsubscribe(operationName: String) {
        if let message = OperationMessage(id: operationName, type: .stop).rawMessage {
            self.write(message)
        }
        self.subscribers.removeValue(forKey: operationName)
        self.subscriptions.removeValue(forKey: operationName)
    }
    
    func requestBody<R: Request>(_ request: R, operationName: String) throws -> GraphQLMap? {
        let query = try request.queryDocument.graphQLString().replacingOccurrences(of: "\n__typename", with: " ")
        
        var body: GraphQLMap = [:]
        if let variables = try request.variables?.graphQLVariablesDictionary() {
            body["variables"] = variables
        }
        
        body["operationName"] = operationName
        body["query"] = query
        
        return body
    }
    
    func write(_ message: String) {
        self.webSocket.write(string: message, completion: nil)
    }
}

// MARK: - Class Method

extension WebSocketClient {
    class func createRequest(baseUrl: String) throws -> URLRequest? {
        let subscriptionUrl = baseUrl.replacingOccurrences(of: "https", with: "wss") + "/subscriptions"
        guard let url = URL(string: subscriptionUrl) else {
            return nil
        }
        
        var defaultHeders = [String: String]()
        defaultHeders["Sec-WebSocket-Protocol"] = "graphql-ws"
        defaultHeders["Origin"] = baseUrl
        
        return try URLRequest(url: url, method: .get, headers: HTTPHeaders(defaultHeders))
    }
}

extension WebSocketClient: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        self.delegate?.didReceive(event: event)
        switch event {
        case .disconnected,
             .cancelled:
            self.subscriptions.removeAll()
            self.subscribers.removeAll()
            self.state = .disconnected
        case .binary(let data):
            self.process(data: data, handler: self.handlePayload)
        case let .text(text):
            self.parse(text: text, handler: self.handlePayload)
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
        case let .reconnectSuggested(shouldReconnect):
            if shouldReconnect {
                self.reconnectWebSocket()
            }
        case .error:
            self.reconnectWebSocket()
        case .ping,
             .pong,
             .viabilityChanged:
            break
        }
    }
    
    func process(data: Data, handler: @escaping (MessagePayload) -> Void) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? GraphQLMap else {
                handler(MessagePayload())
                return
            }
            
            let id = json[OperationMessage.Key.id.rawValue] as? String
            let type = OperationMessage.Types(rawValue: json[OperationMessage.Key.type.rawValue] as? String ?? "")
            guard let payload = json[OperationMessage.Key.payload.rawValue] as? GraphQLMap else {
                handler(MessagePayload())
                return
            }
            
            let payloadData = try JSONSerialization.data(withJSONObject: payload, options:.fragmentsAllowed)
            handler(MessagePayload(id: id, type: type, payload: payloadData))
        }
        catch let error {
            handler(MessagePayload(error: error))
        }
    }
    
    func parse(text: String, handler: @escaping (MessagePayload) -> Void) {
        guard let data = text.data(using: .utf8) else {
            handler(MessagePayload())
            return
        }
        
        self.process(data: data, handler: handler)
    }
    
    func handlePayload(_ payload: MessagePayload) {
        guard let id = payload.id, let completion = self.subscribers[id] else {
            return
        }
        
        if let error = payload.error {
            completion(.failure(error))
        }
        else if let data = payload.payload, payload.type == .data  {
            completion(.success(data))
        }
    }
    
    func connectionInitiated() {
        if let message = OperationMessage(type: .connectionInit).rawMessage {
            self.write(message)
        }
    }
    
    func reconnectWebSocket() {
        guard self.attemptReconnectCount > 0 else {
            self.disconnect()
            return
        }
        
        self.attemptReconnectCount -= 1
        self.state = .disconnected
        self.webSocket.disconnect()
        self.webSocket.connect()
    }
}

final class OperationMessage {
    enum Types : String {
        case connectionInit = "connection_init"            // Client -> Server
        case connectionTerminate = "connection_terminate"  // Client -> Server
        case start = "start"                               // Client -> Server
        case stop = "stop"                                 // Client -> Server
        
        case connectionAck = "connection_ack"              // Server -> Client
        case connectionError = "connection_error"          // Server -> Client
        case connectionKeepAlive = "ka"                    // Server -> Client
        case data = "data"                                 // Server -> Client
        case error = "error"                               // Server -> Client
        case complete = "complete"                         // Server -> Client
    }
    
    enum Key: String {
        case id
        case type
        case payload
    }
    
    var message: GraphQLMap = [:]
    var serialized: String?
    
    var rawMessage: String? {
        guard let serialized = try? JSONSerialization.data(withJSONObject: self.message, options: .fragmentsAllowed) else {
            return nil
        }
        
        return String(data: serialized, encoding: .utf8)
    }
    
    init(payload: GraphQLMap? = nil,
         id: String? = nil,
         type: Types = .start) {
        if let payload = payload {
            self.message[Key.payload.rawValue] = payload
        }
        
        if let id = id  {
            self.message[Key.id.rawValue] = id
        }
        
        self.message[Key.type.rawValue] = type.rawValue
    }
}

struct MessagePayload {
    let id: String?
    let payload: Data?
    let type: OperationMessage.Types?
    let error: Error?
    
    init(id: String? = nil,
         type: OperationMessage.Types? = nil,
         payload: Data? = nil,
         error: Error? = nil) {
        self.id = id
        self.type = type
        self.payload = payload
        self.error = error
    }
}
