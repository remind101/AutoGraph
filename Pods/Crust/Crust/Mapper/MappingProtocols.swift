import Foundation
import JSONValueRX

public struct MappingOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    public static let None = MappingOptions(rawValue: 0)
    public static let AllowDuplicatesInCollection = MappingOptions(rawValue: 1)
}

public protocol Mapping {
    associatedtype MappedObject
    associatedtype AdaptorKind: Adaptor
    
    var adaptor: AdaptorKind { get }
    var primaryKeys: [String : Keypath]? { get }
    
    func mapping(tomap: inout MappedObject, context: MappingContext)
}

public protocol Adaptor {
    associatedtype BaseType
    associatedtype ResultsType: Collection
    
    func mappingBegins() throws
    func mappingEnded() throws
    func mappingErrored(_ error: Error)
    
    func fetchObjects(type: BaseType.Type, keyValues: [String : CVarArg]) -> ResultsType?
    func createObject(type: BaseType.Type) throws -> BaseType
    func deleteObject(_ obj: BaseType) throws
    func save(objects: [ BaseType ]) throws
}

public protocol Transform: AnyMapping {
    func fromJSON(_ json: JSONValue) throws -> MappedObject
    func toJSON(_ obj: MappedObject) -> JSONValue
}

public extension Transform {
    func mapping(tomap: inout MappedObject, context: MappingContext) {
        switch context.dir {
        case .fromJSON:
            do {
                try tomap = self.fromJSON(context.json)
            } catch let err as NSError {
                context.error = err
            }
        case .toJSON:
            context.json = self.toJSON(tomap)
        }
    }
}

public enum Spec<T: Mapping>: Keypath {
    case mapping(Keypath, T)
    indirect case mappingOptions(Spec, MappingOptions)
    
    public var keyPath: String {
        switch self {
        case .mapping(let keyPath, _):
            return keyPath.keyPath
        case .mappingOptions(let keyPath, _):
            return keyPath.keyPath
        }
    }
    
    public var options: MappingOptions {
        switch self {
        case .mappingOptions(_, let options):
            return options
        default:
            return [ .None ]
        }
    }
    
    public var mapping: T {
        switch self {
        case .mapping(_, let mapping):
            return mapping
        case .mappingOptions(let mapping, _):
            return mapping.mapping
        }
    }
}

// TODO: Move into JSONValue lib.
extension NSDate: JSONable {
    public static func fromJSON(_ x: JSONValue) -> NSDate? {
        return Date.fromJSON(x) as NSDate?
    }
    
    public static func toJSON(_ x: NSDate) -> JSONValue {
        return Date.toJSON(x as Date)
    }
}
