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

public typealias RequestCompletion<T: Request> = (_ result: Result<T.Mapping.MappedObject>) -> ()

public class AutoGraph {
    public static var url = "http://localhost:8080/graphql"
    
    public class func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T>) {
        
        Alamofire.request(url, parameters: ["query" : request.query.graphQLString]).responseJSON { response in
            
            self.handle(request, response: response, completion: completion)
        }
    }
    
    class func handle<T: Request>(_ request: T, response: DataResponse<Any>, completion: @escaping RequestCompletion<T>) {
        do {
            
            let value: Any = try {
                switch response.result {
                case .success(let value):
                    return value
                case .failure(let e):
                    throw AutoGraphError.network(error: e)
                }
            }()
            
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
