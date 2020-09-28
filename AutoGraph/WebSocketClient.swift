import Foundation
import Starscream
import Alamofire

public typealias SerializedObject = Decodable
public typealias WebSocketCompletionBlock = (Result<SerializedObject, Error>) -> Void

public protocol WebSocketClientDelegate {
    func didReceive(event: WebSocketEvent)
}

public typealias GraphQLMap = [String: Any]

open class WebSocketClient {
    let queue: DispatchQueue
    let webSocket: WebSocket
    public var delegate: WebSocketClientDelegate?
    private var subscribers = [String: WebSocketCompletionBlock]()
    private var subscriberType = [String: Decodable.Type]()
    private var subscriptions : [String: String] = [:]

    public init?(baseUrl: String,
                 queue: DispatchQueue = DispatchQueue(label:  "com.autograph.WebSocketClient", qos: .background),
                 httpHeaders: [String: String] = [:]) {
        self.queue = queue
        do  {
            guard let request = try WebSocketClient.createRequest(baseUrl: baseUrl, header: httpHeaders) else {
                return nil
            }
            
            self.webSocket = WebSocket(request: request)
            self.webSocket.connect()
        }
        catch {
            return nil
        }
    }
    
    public func disconnect() {
        self.webSocket.disconnect()
        self.subscriptions.removeAll()
        self.subscribers.removeAll()
    }
    
    open func subscribe<R: Request>(_ request: R, completion: @escaping WebSocketCompletionBlock) {
        
        do {
            guard let body = try self.requestBody(request) else {
                return
            }
            
            guard let message = OperationMessage(payload: body, id: request.rootKeyPath).rawMessage else {
                return
            }
            
            self.queue.async {
                self.subscriberType[request.rootKeyPath] = R.SerializedObject.self
                self.subscribers[request.rootKeyPath] = completion
                self.subscriptions[request.rootKeyPath] = message
                self.webSocket.write(string: message, completion: nil)
            }
        }
        catch let error {
            completion(.failure(error))
        }
    }
    
    private func requestBody<R: Request>(_ request: R) throws -> GraphQLMap? {
        let query = try request.queryDocument.graphQLString()
        var body: GraphQLMap = ["query" : query]
        if let variables = try request.variables?.graphQLVariablesDictionary() {
            body["variables"] = variables
        }
        
        return body
    }
    
    private func unsubscribe(key: String) {
        self.subscribers.removeValue(forKey: key)
        self.subscriptions.removeValue(forKey: key)
        self.subscriberType.removeValue(forKey: key)
    }
}

// MARK: - Class Method

extension WebSocketClient {
    class func createRequest(baseUrl: String, header: [String: String]) throws -> URLRequest? {
        guard let url = URL(string: baseUrl) else {
            return nil
        }
        
        return try URLRequest(url: url, method: .post, headers: HTTPHeaders(header))
    }
}

extension WebSocketClient: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        self.delegate?.didReceive(event: event)
        switch event {
        case .disconnected:
            self.disconnect()
        case .binary(let data):
            self.process(data: data)
        case .error,
             .cancelled,
             .connected,
             .text,
             .ping,
             .pong,
             .reconnectSuggested,
             .viabilityChanged:
            break
        }
    }
    
    private func process(data: Data) {
        do {
            guard let json =  try JSONSerialization.jsonObject(with: data, options: []) as? GraphQLMap,
                let id = json["id"] as? String,
                let payload = json["payload"] as? GraphQLMap else {
                return
            }
            
            print(id)
            print(payload)
           
        }
        catch  { }
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
    
    var message: GraphQLMap = [:]
    
    var rawMessage: String? {
        guard let serialized = try? JSONSerialization.data(withJSONObject: self.message, options: .fragmentsAllowed) else {
            return nil
        }
        
        return String(data: serialized, encoding: .utf8)
    }
    
    init(payload: GraphQLMap?,
         id: String? = nil,
         type: Types = .start) {
        if let payload = payload {
            self.message["payload"] = payload
        }
        
        if let id = id  {
            self.message["id"] = id
        }
        
        self.message["type"] = type.rawValue
    }
}
