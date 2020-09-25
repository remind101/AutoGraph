import Foundation
import Starscream

public typealias WebSocketCompletionBlock = (Result<WebSocketClient.Events, Error>) -> Void

open class WebSocketClient {
    public typealias SerializedObject = Decodable

    public enum Events {
        case connected([String: String])
        case disconnected(String, UInt16)
        case data(SerializedObject)
        case pong(Data?)
        case ping(Data?)
        case error(Error?)
    }
    
    public let baseUrl: String
    public var httpHeaders: [String : String]
    public internal(set) var openWebSockets = [StarScream]()
    
    public init(baseUrl: String,
                httpHeaders: [String : String] = [:]) {
        self.baseUrl = baseUrl
        self.httpHeaders = httpHeaders
    }
    
    open func subscribe<R: Request>(_ request: R, completion: @escaping WebSocketCompletionBlock) {
        do {
            let query = try request.queryDocument.graphQLString()
            var parameters: [String : Any] = ["query" : query]
            if let variables = try request.variables?.graphQLVariablesDictionary() {
                parameters["variables"] = variables
            }
            
            guard let url = URL(string: self.baseUrl) else {
                return
            }
            
            let request = try URLRequest(url: url, method: .post)
            let starScream = StarScream(request: request) { (eventReceiver) in
                DispatchQueue.main.async {
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
                    case let .ping(data):
                        completion(.success(.ping(data)))
                    case let .pong(data):
                        completion(.success(.pong(data)))
                    case let .error(error):
                        if let error = error {
                            completion(.failure(error))
                        }
                        
                        self.remove(starScream: eventReceiver.starScream)
                    case .cancelled:
                        self.remove(starScream: eventReceiver.starScream)
                    case .text,
                         .viabilityChanged,
                         .reconnectSuggested:
                        break
                    }
                }
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
}

public class StarScream {
    typealias EventReceiver = (starScream: StarScream, event: WebSocketEvent)
    
    let webSocket: WebSocket
    let eventReceiver: (EventReceiver) -> Void
    
    init(request: URLRequest, eventReceiver: @escaping ((EventReceiver) -> Void)) {
        self.webSocket = WebSocket(request: request)
        self.eventReceiver = eventReceiver
    }
    
    deinit {
        self.webSocket.disconnect()
    }
    
    func connect() {
        self.webSocket.connect()
    }
    
    func disconnect() {
        self.webSocket.disconnect()
    }
}

extension StarScream: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        self.eventReceiver((self, event))
    }
}
