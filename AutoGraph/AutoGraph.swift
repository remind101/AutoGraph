import Foundation
import Alamofire
import Crust
import JSONValueRX
import QueryBuilder

protocol Request {
    associatedtype Mapping: Crust.Mapping
    
    var query: QueryBuilder.Operation { get }
    var mapping: Mapping { get }
}

typealias RequestCompletion<T: Request> = (_ object: T.Mapping.MappedObject?, _ error: Error?) -> ()

class AutoGraph {
    static var url = "http://localhost:8080/graphql"
    class func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T>) {
        
        Alamofire.request(url, parameters: ["query" : request.query.graphQLString]).responseJSON { response in
            
            do {
                let value = response.result.value!
                let json = try JSONValue(object: value)
                let mapper = CRMapper<T.Mapping.MappedObject, T.Mapping>()
                let result = try mapper.mapFromJSONToNewObject(json, mapping: request.mapping)
                completion(result, nil)
            }
            catch let e {
                completion(nil, e)
            }
        }
    }
}
