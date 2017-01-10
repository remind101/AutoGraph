import Alamofire
import Crust
import Foundation
import JSONValueRX

class ResponseHandler {
    
    func handle<Mapping: Crust.Mapping>(response: DataResponse<Any>, mapping: Mapping, completion: @escaping RequestCompletion<Mapping>) {
        
        do {
            let value: Any = try {
                switch response.result {
                case .success(let value):
                    return value
                    
                case .failure(let e):
                    
                    let gqlError: AutoGraphError? = {
                        guard let value = Alamofire.Request.serializeResponseJSON(
                            options: .allowFragments,
                            response: response.response,
                            data: response.data, error: nil).value,
                            let json = try? JSONValue(object: value) else {
                                
                                return nil
                        }
                        
                        return AutoGraphError(graphQLResponseJSON: json)
                    }()
                    
                    throw AutoGraphError.network(error: e, underlying: gqlError)
                }
                }()
            
            let json = try JSONValue(object: value)
            
            if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                throw queryError
            }
            
            do {
                let mapper = CRMapper<Mapping>()
                let result = try mapper.mapFromJSONToNewObject(json, mapping: mapping)
                completion(.success(result))
            }
            catch let e {
                throw AutoGraphError.mapping(error: e)
            }
        }
        catch let e {
            completion(.failure(e))
        }
    }
}
