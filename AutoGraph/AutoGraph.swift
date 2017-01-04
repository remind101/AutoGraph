import Foundation
import Alamofire
import Crust
import JSONValueRX
import QueryBuilder

public protocol Request {
    associatedtype Mapping: Crust.Mapping
    
    var query: QueryBuilder.Operation { get }
    var mapping: Mapping { get }
}

typealias RequestCompletion<T: Request> = (_ result: Result<T.Mapping.MappedObject>) -> ()

class AutoGraph {
    static var url = "http://localhost:8080/graphql"
    class func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T>) {
        
        Alamofire.request(url, parameters: ["query" : request.query.graphQLString]).responseJSON { response in
            
            do {
                let value = response.result.value!
                let json = try JSONValue(object: value)
                
                if let queryError = AutoGraphError(graphQLJSON: json) {
                    throw queryError
                }
                
                do {
                    let mapper = CRMapper<T.Mapping.MappedObject, T.Mapping>()
                    let result = try mapper.mapFromJSONToNewObject(json, mapping: request.mapping)
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
}
