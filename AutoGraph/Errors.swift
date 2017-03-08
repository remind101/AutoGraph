import Foundation
import JSONValueRX

/*
 GraphQL errors have the following form:
 
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

public indirect enum AutoGraphError: LocalizedError {
    case graphQL(errors: [GraphQLError])
    case network(error: Error, response: HTTPURLResponse?, underlying: AutoGraphError?)
    case mapping(error: Error)
    case refetching
    case invalidResponse
    
    public init?(graphQLResponseJSON: JSONValue) {
        guard let errorsJSON = graphQLResponseJSON["errors"] else {
            return nil
        }
        
        guard case .array(let errors) = errorsJSON else {
            self = .invalidResponse
            return
        }
        
        self = .graphQL(errors: errors.flatMap { GraphQLError(json: $0) })
        return
    }
    
    public var errorDescription: String? {
        switch self {
        case .graphQL(let errors):
            return errors.flatMap { $0.localizedDescription }.joined(separator: "\n")
            
        case .network(let error, _, let underlying):
            return "Network Failure: " + error.localizedDescription + "\n" + (underlying?.localizedDescription ?? "")
            
        case .mapping(let error):
            return "Mapping Failure: " + error.localizedDescription
        
        case .refetching:
            return "Failed to refetch data on main thread"
        
        case .invalidResponse:
            return self.localizedDescription
        }
    }
}

public struct GraphQLError: LocalizedError {
    
    public struct Location: CustomStringConvertible {
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
    }
    
    public let message: String
    public let locations: [Location]
    
    public var errorDescription: String? {
        return "GraphQL error message: \(self.message), locations: \(self.locations)"
    }
    
    init(json: JSONValue) {
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
}
