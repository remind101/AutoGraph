import Alamofire
import Crust
import Foundation
import JSONValueRX

public enum Result<Value> {
    case success(Value)
    case failure(Error)
    
    public func map<U>(_ transform: (Value) -> U) -> Result<U> {
        switch self {
        case .success(let val):
            return .success(transform(val))
        case .failure(let e):
            return .failure(e)
        }
    }
    
    public func flatMap<U>(_ transform: (Value) -> Result<U>) -> Result<U> {
        switch self {
        case .success(let val):
            return transform(val)
        case .failure(let e):
            return .failure(e)
        }
    }
}

extension DataResponse {
    func extractValue() throws -> Any {
        switch self.result {
        case .success(let value):
            return value
            
        case .failure(let e):
            
            let gqlError: AutoGraphError? = {
                guard let value = Alamofire.Request.serializeResponseJSON(
                    options: .allowFragments,
                    response: self.response,
                    data: self.data, error: nil).value,
                let json = try? JSONValue(object: value) else {
                        
                        return nil
                }
                
                return AutoGraphError(graphQLResponseJSON: json, networkErrorParser: nil)
            }()
            
            throw AutoGraphError.network(error: e, statusCode: self.response?.statusCode ?? -1, response: self.response, underlying: gqlError)
        }
    }
    
    func extractJSON(networkErrorParser: @escaping NetworkErrorParser) throws -> JSONValue {
        let value = try self.extractValue()
        let json = try JSONValue(object: value)
        
        if let queryError = AutoGraphError(graphQLResponseJSON: json, networkErrorParser: networkErrorParser) {
            throw queryError
        }
        
        return json
    }
}
