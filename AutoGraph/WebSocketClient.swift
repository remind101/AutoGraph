import Foundation
import Starscream
import Alamofire

public typealias WebSocketCompletionBlock = (Result<WebSocketClient.Events, Error>) -> Void

public protocol WebSocketClientDelegate {
    func didReceive(event: WebSocketEvent)
}

open class WebSocketClient {
    public typealias SerializedObject = Decodable

    public enum Events {
        case connected([String: String])
        case disconnected(String, UInt16)
        case data(SerializedObject)
        case error(Error?)
    }
    
    public let baseUrl: String
    public var httpHeaders: [String : String]
    public internal(set) var openWebSockets = [StarScream]()
    public var delegate: WebSocketClientDelegate?
    
    public init(baseUrl: String,
                delegate: WebSocketClientDelegate? = nil,
                httpHeaders: [String : String] = [:]) {
        self.baseUrl = baseUrl
        self.delegate = delegate
        self.httpHeaders = httpHeaders
    }
    
    open func subscribe<R: Request>(_ request: R, completion: @escaping WebSocketCompletionBlock) {
        do {
            guard let starScream = try self.createStarScream(request: request, completion: completion) else {
                return
            }
            
            self.openWebSockets.append(starScream)
            starScream.connect()
        }
        catch let error {
            completion(.failure(error))
        }
    }
    
    public func setAuthToken(_ token: String) {
        self.httpHeaders["Authorization"] = "Bearer \(token)"
    }
    
    public func cancelAll() {
        self.openWebSockets.removeAll()
    }
    
    private func remove(starScream: StarScream) {
        self.openWebSockets.removeAll(where: { $0 === starScream })
    }

    private func createStarScream<R: Request>(request: R, completion: @escaping WebSocketCompletionBlock) throws -> StarScream? {
        guard let urlRequest = try self.createRequest(request) else {
            return nil
        }
        
        let dispatchQueue = DispatchQueue(label: request.rootKeyPath, qos: .background)
        return StarScream(request: urlRequest, dispatchQueue: dispatchQueue) { [weak self] (eventReceiver) in
            self?.delegate?.didReceive(event: eventReceiver.event)
            
            switch eventReceiver.event {
            case .connected(let headers):
                completion(.success(.connected(headers)))
            case let .disconnected(reason, code):
                completion(.success(.disconnected(reason, code)))
            case .binary(let data):
                do {
                    let decoder = JSONDecoder()
                    let object = try decoder.decode(R.SerializedObject.self, from: data)
                    completion(.success(.data(object)))
                }
                catch let error {
                    completion(.failure(error))
                }
            case let .error(error):
                if let error = error {
                    completion(.failure(error))
                }
                
                self?.remove(starScream: eventReceiver.starScream)
            case .cancelled:
                self?.remove(starScream: eventReceiver.starScream)
            case let .reconnectSuggested(shouldReconnect):
                if shouldReconnect {
                    eventReceiver.starScream.reconnect()
                }
            case .text,
                 .ping,
                 .pong,
                 .viabilityChanged:
                break
            }
        }
    }
    
    private func createRequest<R: Request>(_ request: R) throws -> URLRequest? {
        let query = try request.queryDocument.graphQLString()
        var parameters: [String : Any] = ["query" : query]
        if let variables = try request.variables?.graphQLVariablesDictionary() {
            parameters["variables"] = variables
        }
        
        guard let url = URL(string: self.baseUrl) else {
            return nil
        }
        
        let request = try URLRequest(url: url, method: .post, headers: HTTPHeaders(self.httpHeaders))
        
        return try URLEncoding.default.encode(request, with: parameters)
    }
}

public class StarScream {
    typealias EventReceiver = (starScream: StarScream, event: WebSocketEvent)
    
    var webSocket: WebSocket?
    let request: URLRequest
    let eventReceiver: (EventReceiver) -> Void
    
    init(request: URLRequest,
         dispatchQueue: DispatchQueue,
         eventReceiver: @escaping ((EventReceiver) -> Void)) {
        self.request = request
        self.webSocket = WebSocket(request: request)
        self.webSocket?.callbackQueue = dispatchQueue
        self.eventReceiver = eventReceiver
    }
    
    deinit {
        self.webSocket?.forceDisconnect()
        self.webSocket = nil
    }
    
    func connect() {
        self.webSocket?.connect()
    }
    
    func disconnect() {
        self.webSocket?.disconnect()
    }
    
    func forceDisconnect() {
        self.webSocket?.forceDisconnect()
    }
    
    func reconnect() {
        self.webSocket = WebSocket(request: self.request)
        self.webSocket?.connect()
    }
}

extension StarScream: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        self.eventReceiver((self, event))
    }
}
