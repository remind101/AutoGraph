import Foundation

public protocol SubscriptionRequestSerializable {
    func serializedSubscriptionPayload() throws -> String
}

public struct SubscriptionRequest<R: Request>: SubscriptionRequestSerializable {
    let operationName: String
    let request: R
    let subscriptionID: SubscriptionID
    
    init(request: R, operationName: String) throws {
        self.operationName = operationName
        self.request = request
        self.subscriptionID = try SubscriptionRequest.generateSubscriptionID(request: request,
                                                                             operationName: operationName)
    }
    
    // TODO: could possible input start or stop here depending on need.
    public func serializedSubscriptionPayload() throws -> String {
        let query = try self.request.queryDocument.graphQLString()
        
        var body: [String : Any] = [
            "operationName": operationName,
            "query": query
        ]
        
        if let variables = try self.request.variables?.graphQLVariablesDictionary() {
            body["variables"] = variables
        }
        
        let payload: [String : Any] = [
            "payload": body,
            "id": self.subscriptionID,
            "type": GraphQLWSProtocol.start.rawValue
        ]
        
        let serialized: Data = try {
            do {
               return try JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
            }
            catch let e {
                throw WebSocketError.subscriptionPayloadFailedSerialization(payload, underlyingError: e)
            }
        }()
        
        // TODO: Do we need to convert this to a string?
        guard let serializedString = String(data: serialized, encoding: .utf8) else {
            throw WebSocketError.subscriptionPayloadFailedSerialization(payload, underlyingError: nil)
        }
        
        return serializedString
    }
    
    static func generateSubscriptionID<R: Request>(request: R, operationName: String) throws -> SubscriptionID {
        let start = "\(operationName):{"
        let id = try request.variables?.graphQLVariablesDictionary().reduce(into: start, { (result, arg1) in
            guard let value = arg1.value as? String, let key = arg1.key as? String else {
                return
            }
            
            result += "\(key) : \(value),"
        }) ?? operationName
        
        return id + "}"
    }
}

public enum GraphQLWSProtocol: String {
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
    
    public func serializedSubscriptionPayload(id: String? = nil) throws -> String {
        var payload: [String : Any] = [
            "type": self.rawValue
        ]
        
        if let id = id {
            payload["id"] = id
        }
        let serialized: Data = try {
            do {
               return try JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
            }
            catch let e {
                throw WebSocketError.subscriptionPayloadFailedSerialization(payload, underlyingError: e)
            }
        }()
        
        // TODO: Do we need to convert this to a string?
        guard let serializedString = String(data: serialized, encoding: .utf8) else {
            throw WebSocketError.subscriptionPayloadFailedSerialization(payload, underlyingError: nil)
        }
        
        return serializedString
    }
}
