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
