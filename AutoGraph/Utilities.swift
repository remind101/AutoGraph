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

public protocol ArraySubMapping: Mapping {
    init(adaptor: AdaptorKind)
}

open class ArrayMapping<SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>: Mapping
where SubAdaptor.BaseType == SubType, SubAdaptor.ResultsType == [SubType],
SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType {
    
    public typealias MappedObject = [SubType]
    public typealias AdaptorKind = ArrayAdaptor<SubType, SubAdaptor>
    
    public let adaptor: ArrayAdaptor<SubType, SubAdaptor>
    
    public required init(adaptor: AdaptorKind) {
        self.adaptor = adaptor
    }
    
    public var primaryKeys: [String : Keypath]? { return nil }
    open var keyPath: Keypath { return "" }
    
    public func mapping(tomap: inout [SubType], context: MappingContext) {
        let mapping = SubMapping(adaptor: self.adaptor.subAdaptor)
        _ = tomap <- (.mapping(self.keyPath, mapping), context)
    }
}

open class ArrayAdaptor<SubBaseType, SubAdaptor: Adaptor>: Adaptor
where SubAdaptor.BaseType == SubBaseType, SubAdaptor.ResultsType == [SubBaseType] {
    
    public typealias BaseType = [SubBaseType]
    public typealias ResultsType = [BaseType]
    
    public let subAdaptor: SubAdaptor
    
    public init(subAdaptor: SubAdaptor) {
        self.subAdaptor = subAdaptor
    }
    
    public func mappingBegins() throws {
        try self.subAdaptor.mappingBegins()
    }
    
    public func mappingEnded() throws {
        try self.subAdaptor.mappingEnded()
    }
    
    public func mappingErrored(_ error: Error) {
        self.subAdaptor.mappingErrored(error)
    }
    
    public func fetchObjects(type: BaseType.Type, keyValues: [String : CVarArg]) -> ResultsType? {
        guard let result = self.subAdaptor.fetchObjects(type: SubBaseType.self, keyValues: keyValues) else {
            return nil
        }
        return [result]
    }
    
    public func createObject(type: BaseType.Type) throws -> BaseType {
        return []
    }
    
    public func deleteObject(_ obj: BaseType) throws {
        try obj.forEach {
            try self.subAdaptor.deleteObject($0)
        }
    }
    
    public func save(objects: [BaseType]) throws {
        try objects.forEach {
            try self.subAdaptor.save(objects: $0)
        }
    }
}
