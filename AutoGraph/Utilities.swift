import Alamofire
import Foundation
import JSONValueRX

public typealias AutoGraphResult<Value> = Swift.Result<Value, Error>
public typealias ResultIncludingJSON<Value: Decodable> = AutoGraphResult<DataIncludingNetworkResponse<Value>>

extension DataResponse {
    func extractValue() throws -> Any {
        switch self.result {
        case .success(let value):
            return value
            
        case .failure(let e):
            
            let gqlError: AutoGraphError? = {
                guard let data = self.data, let json = try? JSONValue.decode(data) else {
                        return nil
                }
                
                return AutoGraphError(graphQLResponseJSON: json, response: self.response, networkErrorParser: nil)
            }()
            
            throw AutoGraphError.network(error: e, statusCode: self.response?.statusCode ?? -1, response: self.response, underlying: gqlError)
        }
    }
    
    func extractJSON(networkErrorParser: @escaping NetworkErrorParser) throws -> JSONValue {
        let value = try self.extractValue()
        let json = try JSONValue(object: value)
        
        if let queryError = AutoGraphError(graphQLResponseJSON: json, response: self.response, networkErrorParser: networkErrorParser) {
            throw queryError
        }
        
        return json
    }
}
