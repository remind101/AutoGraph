import Alamofire
import Crust
import Foundation
import JSONValueRX

public enum Result<Value> {
    case success(Value)
    case failure(Error)
    
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
                
                return AutoGraphError(graphQLResponseJSON: json)
            }()
            
            throw AutoGraphError.network(error: e, underlying: gqlError)
        }
    }
}

//extension Adaptor where BaseType: Sequence {
//    func fetchObjects(type: BaseType.Iterator.Element.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> [BaseType.Iterator.Element]? {
//        
//        guard let result = self.subAdaptor.fetchObjects(type: type, primaryKeyValues: primaryKeyValues, isMapping: isMapping) else {
//            return nil
//        }
//        return result
//    }
//}
