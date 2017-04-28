/// `MappedObject` type constraint required in `AnyMapping`.
public protocol AnyMappable {
    init()
}

/// A `Mapping` that does not require an adapter of `typealias AdapterKind`.
/// Use for structs or classes that require no storage when mapping.
public protocol AnyMapping: Mapping {
    associatedtype AdapterKind: AnyAdapter = AnyAdapterImp<MappedObject>
    associatedtype MappedObject: AnyMappable
}

public extension AnyMapping {
    var adapter: AnyAdapterImp<MappedObject> {
        return AnyAdapterImp<MappedObject>()
    }
    
    var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return nil
    }
}

/// Used internally to remove the need for structures conforming to `AnyMapping`
/// to specify a `typealias AdapterKind`.
public struct AnyAdapterImp<T: AnyMappable>: AnyAdapter {
    public typealias BaseType = T
    public init() { }
    public let dataBaseTag: String = DefaultDatabaseTag.none.rawValue
}

/// A bare-bones `Adapter`.
///
/// Conforming to `AnyAdapter` automatically implements the requirements for `Adapter`
/// outside of specifying the `BaseType`.
public protocol AnyAdapter: Adapter {
    associatedtype BaseType: AnyMappable
    associatedtype ResultsType = [BaseType]
}

public extension AnyAdapter {
    
    var isInTransaction: Bool { return false }
    func mappingWillBegin() throws { }
    func mappingDidEnd() throws { }
    func mappingErrored(_ error: Error) { }
    
    func sanitize(primaryKeyProperty property: String, forValue value: CVarArg, ofType type: Self.BaseType.Type) -> CVarArg? {
        return nil
    }
    
    func fetchObjects(type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> [BaseType]? {
        return nil
    }
    
    func createObject(type: BaseType.Type) throws -> BaseType {
        return type.init()
    }
    
    func deleteObject(_ obj: BaseType) throws { }
    func save(objects: [ BaseType ]) throws { }
}
