import Alamofire
import Foundation
import JSONValueRX

public typealias AutoGraphResult<Value> = Swift.Result<Value, Error>
public typealias ResultIncludingJSON<Value: Decodable> = AutoGraphResult<DataIncludingJSON<Value>>

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
                
                return AutoGraphError(graphQLResponseJSON: json, networkErrorParser: nil, response: self.response)
            }()
            
            throw AutoGraphError.network(error: e, statusCode: self.response?.statusCode ?? -1, response: self.response, underlying: gqlError)
        }
    }
    
    func extractJSON(networkErrorParser: @escaping NetworkErrorParser) throws -> JSONValue {
        let value = try self.extractValue()
        let json = try JSONValue(object: value)
        
        if let queryError = AutoGraphError(graphQLResponseJSON: json, networkErrorParser: networkErrorParser, response: self.response) {
            throw queryError
        }
        
        return json
    }
}
