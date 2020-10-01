import Foundation
import JSONValueRX

/*
 GraphQL errors have the following base shape:
 
 {
    "errors": [
     {
        "message": "Cannot query field \"d\" on type \"Planet\".",
        "locations": [
         {
            "line": 18,
            "column": 7
         }
        ]
     },
     {
        "message": "Fragment \"planet\" is never used.",
        "locations": [
         {
            "line": 23,
            "column": 1
         }
        ]
     }
    ]
 }
 
*/

public protocol NetworkError: Error {
    var statusCode: Int { get }
    var underlyingError: GraphQLError { get }
}
public typealias NetworkErrorParser = (_ graphQLError: GraphQLError) -> NetworkError?

public indirect enum AutoGraphError: LocalizedError {
    case graphQL(errors: [GraphQLError], response: HTTPURLResponse?)
    case network(error: Error, statusCode: Int, response: HTTPURLResponse?, underlying: AutoGraphError?)
    case mapping(error: Error, response: HTTPURLResponse?)
    case invalidResponse(response: HTTPURLResponse?)
    case subscribeWithMissingWebSocketClient
    
    public init?(graphQLResponseJSON: JSONValue, response: HTTPURLResponse?, networkErrorParser: NetworkErrorParser?) {
        guard let errorsJSON = graphQLResponseJSON["errors"] else {
            return nil
        }
        
        guard case .array(let errorsArray) = errorsJSON else {
            self = .invalidResponse(response: response)
            return
        }
        
        let errors = errorsArray.compactMap { GraphQLError(json: $0) }
        let graphQLError = AutoGraphError.graphQL(errors: errors, response: response)
        if let networkError: NetworkError = networkErrorParser.flatMap({
            for error in errors {
                if let networkError = $0(error) {
                    return networkError
                }
            }
            return nil
        })
        {
            self = .network(error: networkError, statusCode: networkError.statusCode, response: nil, underlying: graphQLError)
        }
        else {
            self = .graphQL(errors: errorsArray.compactMap { GraphQLError(json: $0) }, response: response)
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .graphQL(let errors, _):
            return errors.compactMap { $0.localizedDescription }.joined(separator: "\n")
            
        case .network(let error, let statusCode, _, let underlying):
            return "Network Failure - \(statusCode): " + error.localizedDescription + "\n" + (underlying?.localizedDescription ?? "")
            
        case .mapping(let error, _):
            return "Mapping Failure: " + error.localizedDescription
        
        case .invalidResponse:
            return "Invalid Response"
        
        case .subscribeWithMissingWebSocketClient:
            return "Attempting to subscribe to a subscription but AutoGraph was not initialized with a WebSocketClient. Please initialize with a WebSocketClient."
        }
    }
}

public struct GraphQLError: LocalizedError, Equatable {
    
    public struct Location: CustomStringConvertible, Equatable {
        public let line: Int
        public let column: Int
        
        public var description: String {
            return "line: \(line), column: \(column)"
        }
        
        init?(json: JSONValue) {
            guard case .some(.number(let line)) = json["line"] else {
                return nil
            }
            
            guard case .some(.number(let column)) = json["column"] else {
                return nil
            }
            
            self.line = line.asNSNumber.intValue
            self.column = column.asNSNumber.intValue
        }
    }
    
    public let message: String
    public let locations: [Location]
    public let jsonPayload: JSONValue
    
    public var errorDescription: String? {
        return self.message
    }
    
    init(json: JSONValue) {
        self.jsonPayload = json
        self.message = {
            guard case .some(.string(let message)) = json["message"] else {
                return ""
            }
            return message
        }()
        
        self.locations = {
            guard case .some(.array(let locations)) = json["locations"] else {
                return []
            }
            return locations.compactMap { Location(json: $0) }
        }()
    }
    
    public static func == (lhs: GraphQLError, rhs: GraphQLError) -> Bool {
        return lhs.message == rhs.message && lhs.locations == rhs.locations
    }
}
