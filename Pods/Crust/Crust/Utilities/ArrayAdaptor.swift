import Foundation

enum ArrayAdaptorError: Error {
    case subBaseTypeSubAdaptorBaseTypeMismatch
}

public protocol ArraySubMapping: Mapping {
    init(adaptor: AdaptorKind)
}

open class ArrayMapping<SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>: Mapping
    where SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType {

    public typealias MappedObject = [SubType]
    public typealias AdaptorKind = AbstractArrayAdaptor<SubType, SubAdaptor>
    
    public let adaptor: AbstractArrayAdaptor<SubType, SubAdaptor>
    
    public required init(adaptor: AdaptorKind) {
        self.adaptor = adaptor
    }
    
    public var primaryKeys: [String : Keypath]? { return nil }
    open var keyPath: Keypath { return "" }
    open var options: MappingOptions { return MappingOptions.None }
    
    public func mapping(tomap: inout [SubType], context: MappingContext) {
        let mapping = SubMapping(adaptor: self.adaptor.subAdaptor)
        _ = tomap <- (.mappingOptions(.mapping(self.keyPath, mapping), self.options), context)
    }
}

public protocol ArrayAdaptor: Adaptor {
    associatedtype SubBaseType
    associatedtype SubAdaptor: Adaptor
    associatedtype BaseType = [SubBaseType]
    associatedtype ResultsType = SubAdaptor.ResultsType
    
    var subAdaptor: SubAdaptor { get }
    
    func fetchObjects(type: SubAdaptor.BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> SubAdaptor.ResultsType?
}

extension ArrayAdaptor {

    public func mappingBegins() throws {
        try self.subAdaptor.mappingBegins()
    }
    
    public func mappingEnded() throws {
        try self.subAdaptor.mappingEnded()
    }
    
    public func mappingErrored(_ error: Error) {
        self.subAdaptor.mappingErrored(error)
    }
    
    public func createObject(type: [SubBaseType].Type) throws -> [SubBaseType] {
        return [SubBaseType]()
    }
    
    public func deleteObject(_ obj: [SubBaseType]) throws {
        for subObj in obj {
            guard subObj is Self.SubAdaptor.BaseType else {
                throw ArrayAdaptorError.subBaseTypeSubAdaptorBaseTypeMismatch
            }
            try self.subAdaptor.deleteObject(subObj as! Self.SubAdaptor.BaseType)
        }
    }
    
    public func save(objects: [[SubBaseType]]) throws {
        var final: [Self.SubAdaptor.BaseType] = []
        for objs in objects {
            for subObj in objs {
                guard subObj is Self.SubAdaptor.BaseType else {
                    throw ArrayAdaptorError.subBaseTypeSubAdaptorBaseTypeMismatch
                }
                final.append(subObj as! Self.SubAdaptor.BaseType)
            }
        }
        
        try self.subAdaptor.save(objects: final)
    }
    
    public func fetchObjects(type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType? {
        return nil
    }
    
    public func fetchObjects(type: SubAdaptor.BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> SubAdaptor.ResultsType? {
        
        guard let result = self.subAdaptor.fetchObjects(type: type, primaryKeyValues: primaryKeyValues, isMapping: isMapping) else {
            return nil
        }
        return result
    }
}

open class AbstractArrayAdaptor<SBaseType, SAdaptor: Adaptor>: ArrayAdaptor {
    
    public typealias SubBaseType = SBaseType
    public typealias SubAdaptor = SAdaptor
    
    public let subAdaptor: SubAdaptor
    
    public init(subAdaptor: SubAdaptor) {
        self.subAdaptor = subAdaptor
    }
}
