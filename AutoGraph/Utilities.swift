import Crust
import Foundation

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

//extension Adaptor where BaseType: Sequence {
//    func fetchObjects(type: BaseType.Iterator.Element.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> [BaseType.Iterator.Element]? {
//        
//        guard let result = self.subAdaptor.fetchObjects(type: type, primaryKeyValues: primaryKeyValues, isMapping: isMapping) else {
//            return nil
//        }
//        return result
//    }
//}
