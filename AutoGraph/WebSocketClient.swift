import Foundation
import Starscream

open class WebSocketClient {
    public let baseUrl: String
    public var httpHeaders: [String : String]
    public var webSocket: WebSocket?
    public var lifeCycle: GlobalLifeCycle?
    private var webSocketListener: WebSocketListener?
    
    public init(baseUrl: String,
                httpHeaders: [String : String] = [:]) {
        self.baseUrl = baseUrl
        self.httpHeaders = httpHeaders
    }
    
    open func send<R: Request>(_ request: R, completion: @escaping RequestCompletion<R.SerializedObject>) {
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
            
            self.webSocket = WebSocket(request: request)
            self.handleWebSocketListener(with: completion)
            self.webSocket?.delegate = self.webSocketListener
        }
        catch let error {
            completion(.failure(error))
        }
    }
    
    public func setAuthToken(_ token: String) {
        self.httpHeaders["Authorization"] = "Bearer \(token)"
    }
    
    public func disconnect() {
        self.webSocket?.disconnect()
        self.webSocket = nil
        self.webSocketListener = nil
    }
    
    private func handleWebSocketListener<SerializedObject: Decodable>(with completion: @escaping RequestCompletion<SerializedObject>) {
        self.webSocketListener = WebSocketListener { (action) in
            switch action {
            case .connected:
                break
            case let .data(data):
                do {
                    let decoder = JSONDecoder()
                    let object = try decoder.decode(SerializedObject.self, from: data)
                    completion(.success(object))
                }
                catch let error {
                    completion(.failure(error))
                }
            case .cancelled:
                self.disconnect()
            case let .error(error):
                if let error = error {
                    completion(.failure(error))
                }
            case .disconnected:
                self.disconnect()
            }
        }
    }
}

class WebSocketListener {
    enum Action {
        case connected([String: String])
        case disconnected(String, UInt16)
        case data(Data)
        case error(Error?)
        case cancelled
    }
    
    let actionHandler: (Action) -> Void
    
    init(actionHandler: @escaping (Action) -> Void) {
        self.actionHandler = actionHandler
    }
}

extension WebSocketListener: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            self.actionHandler(.connected(headers))
        case let .disconnected(reason, code):
            self.actionHandler(.disconnected(reason, code))
        case .binary(let data):
            self.actionHandler(.data(data))

        case .cancelled:
            self.actionHandler(.cancelled)
        case let .error(error):
            self.actionHandler(.error(error))
//            if let error = error {
//                self.completion?(.failure(error))
//            }
//            self.disconnect()
        case .ping,
             .text,
             .pong,
             .viabilityChanged,
             .reconnectSuggested:
            break
        }
    }
}
