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
    case graphQL(errors: [GraphQLError])
    case network(error: Error, statusCode: Int, response: HTTPURLResponse?, underlying: AutoGraphError?)
    case mapping(error: Error)
    case refetching(error: Error?)
    case typeCoercion(from: Any.Type, to: Any.Type)
    case invalidResponse
    
    public init?(graphQLResponseJSON: JSONValue, networkErrorParser: NetworkErrorParser?) {
        guard let errorsJSON = graphQLResponseJSON["errors"] else {
            return nil
        }
        
        guard case .array(let errorsArray) = errorsJSON else {
            self = .invalidResponse
            return
        }
        
        let errors = errorsArray.flatMap { GraphQLError(json: $0) }
        let graphQLError = AutoGraphError.graphQL(errors: errors)
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
            self = .graphQL(errors: errorsArray.flatMap { GraphQLError(json: $0) })
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .graphQL(let errors):
            return errors.flatMap { $0.localizedDescription }.joined(separator: "\n")
            
        case .network(let error, let statusCode, _, let underlying):
            return "Network Failure - \(statusCode): " + error.localizedDescription + "\n" + (underlying?.localizedDescription ?? "")
            
        case .mapping(let error):
            return "Mapping Failure: " + error.localizedDescription
        
        case .refetching(let error):
            let baseMessage = "Failed to refetch data on main thread"
            if let message = error?.localizedDescription {
                return baseMessage + ": \(message)"
            }
            
            return baseMessage
        
        case .typeCoercion(from: let from, to: let to):
            return "Type \(from) cannot be cast to type \(to)"
            
        case .invalidResponse:
            return self.localizedDescription
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
            
            self.line = Int(line)
            self.column = Int(column)
        }
        
        public static func ==(lhs: Location, rhs: Location) -> Bool {
            return lhs.line == rhs.line && lhs.column == rhs.column
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
            return locations.flatMap { Location(json: $0) }
        }()
    }
    
    public static func ==(lhs: GraphQLError, rhs: GraphQLError) -> Bool {
        return lhs.message == rhs.message && lhs.locations == rhs.locations
    }
}
