import Foundation
import JSONValueRX

public enum CollectionInsertionMethod<Element> {
    case append
    case replace(delete: ((_ orphansToDelete: AnyCollection<Element>) -> AnyCollection<Element>)?)
}

public typealias CollectionUpdatePolicy<Element> =
    (insert: CollectionInsertionMethod<Element>, unique: Bool, nullable: Bool)

public enum Binding<K: MappingKey, M: Mapping> {
    
    case mapping(K, M)
    case collectionMapping(K, M, CollectionUpdatePolicy<M.MappedObject>)
    
    public var keyPath: String {
        switch self {
        case .mapping(let key, _):
            return key.keyPath
        case .collectionMapping(let key, _, _):
            return key.keyPath
        }
    }
    
    public var key: K {
        switch self {
        case .mapping(let key, _):
            return key
        case .collectionMapping(let key, _, _):
            return key
        }
    }
    
    public var mapping: M {
        switch self {
        case .mapping(_, let mapping):
            return mapping
        case .collectionMapping(_, let mapping, _):
            return mapping
        }
    }
    
    public var collectionUpdatePolicy: CollectionUpdatePolicy<M.MappedObject> {
        switch self {
        case .mapping(_, _):
            return (.replace(delete: nil), true, true)
        case .collectionMapping(_, _, let method):
            return method
        }
    }
    
    internal func nestedBinding(`for` nestedKeys: M.MappingKeyType)
        -> Binding<M.MappingKeyType, M> {
            switch self {
            case .mapping(_, let mapping):
                return .mapping(nestedKeys, mapping)
            case .collectionMapping(_, let mapping, let method):
                return .collectionMapping(nestedKeys, mapping, method)
            }
    }
}

public protocol Mapping {
    /// The class, struct, enum type we are mapping to.
    associatedtype MappedObject
    
    /// The DB adapter type.
    associatedtype AdapterKind: Adapter
    
    associatedtype MappingKeyType: MappingKey
    
    var adapter: AdapterKind { get }
    
    typealias PrimaryKeyTransform = (JSONValue, MappingPayload<AnyMappingKey>?) throws -> CVarArg?
    /// Describes a primary key on the `MappedObject`.
    /// - property: Primary key property name on `MappedObject`.
    /// - keyPath: The key path into the JSON blob to retrieve the primary key's value.
    ///             A `nil` value returns the whole JSON blob for this object.
    /// - transform: Transform executed on the retrieved primary key's value before usage. The
    ///             JSON returned from `keyPath` is passed into this transform. The full parent payload is additionally
    ///             handed in for arbitrary usage, such as mapping from a uuid in the parent object.
    ///             A `nil` `transform` or `nil` returned value means the JSON value is not tranformed before
    ///             being used. Can `throw` an error which stops mapping and returns the error to the caller.
    typealias PrimaryKeyDescriptor = (property: String, keyPath: String?, transform: PrimaryKeyTransform?)
    
    /// The primaryKeys on `MappedObject`. Primary keys are mapped separately from what is mapped in
    /// `mapping(toMap:payload:)` and are never remapped to objects fetched from the database.
    var primaryKeys: [PrimaryKeyDescriptor]? { get }
    
    /// Override to perform mappings to properties.
    func mapping(toMap: inout MappedObject, payload: MappingPayload<MappingKeyType>) throws
}

public enum DefaultDatabaseTag: String {
    case realm = "Realm"
    case coreData = "CoreData"
    case none = "None"
}

/// An Adapter to use to write and read objects from a persistance layer.
public protocol Adapter {
    /// The type of object being mapped to. If Realm then RLMObject or Object. If Core Data then NSManagedObject.
    associatedtype BaseType
    
    /// The type of returned results after a fetch.
    associatedtype ResultsType: Collection
    
    /// Informs the caller if the Adapter is currently within a transaction. The type which inherits Adapter
    /// will generally set this value to `true` explicitly or implicitly in the call to `mappingWillBegin` 
    /// `false` in the call to `mappingDidEnd`.
    ///
    /// The `Mapper` will check for this value before calling `mappingWillBegin`, and if `true` will _not_ call `mappingWillBegin`
    /// and if `false` will call `mappingWillBegin`, even in nested object mappings.
    var isInTransaction: Bool { get }
    
    /// Used to designate the database type being written to by this adapter. This is checked before calls to `mappingWillBegin` and
    /// `mappingDidEnd`. If the same `dataBaseTag` is used for a nested mapping as a parent mapping, then `mappingWillBegin` and
    /// `mappingDidEnd` will not be called for the nested mapping. This prevents illegal recursive transactions from being started during mapping.
    /// `DefaultDatabaseTag` provides some defaults to use for often use iOS databases, or none at all.
    var dataBaseTag: String { get }
    
    /// Called at the beginning of mapping a json blob. Good place to start a write transaction. Will only
    /// be called once at the beginning of a tree of nested objects being mapped assuming `isInTransaction` is set to
    /// `true` during that first call.
    func mappingWillBegin() throws
    
    /// Called at the end of mapping a json blob. Good place to close a write transaction. Will only
    /// be called once at the end of a tree of nested objects being mapped.
    func mappingDidEnd() throws
    
    /// Called if mapping errored. Good place to cancel a write transaction. Mapping will no longer
    /// continue after this is called.
    func mappingErrored(_ error: Error)
    
    /// Use this to globally transform the value of primary keys before they are mapped.
    /// E.g. our JSON model uses Double for numbers. If the primary key is an Int you must
    /// either transform the primary key in the mapping or you can dynamically check if the
    /// property is an Int here and transform Double to properties of Int in all cases.
    func sanitize(primaryKeyProperty property: String, forValue value: CVarArg, ofType type: BaseType.Type) -> CVarArg?
    
    /// Fetch objects from local persistance.
    ///
    /// - parameter type: The type of object being returned by the query
    /// - parameter primaryKeyValues: An Array of of Dictionaries of primary keys to values to query. Each
    ///     Dictionary is a query for a single object with possible composite keys (multiple primary keys).
    ///
    ///     The query should have a form similar to "Dict0Key0 == Dict0Val0 AND Dict0Key1 == Dict0Val1 OR
    ///     Dict1Key0 == Dict1Val0 AND Dict1Key1 == Dict1Val1" etc. Where Dict0 is the first dictionary in the
    ///     array and contains all the primary key/value pairs to search for for a single object of type `type`.
    /// - parameter isMapping: Indicates whether or not we're in the process of mapping an object. If `true` then
    ///     the `Adapter` may need to avoid querying the store since the returned object's primary key may be written
    ///     to if available. If this is the case, the `Adapter` may need to return any objects cached in memory during the current
    ///     mapping process, not query the persistance layer.
    /// - returns: Results of the query.
    func fetchObjects(type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType?
    
    /// Create a default object of type `BaseType`. This is called between `mappingWillBegin` and `mappingDidEnd` and
    /// will be the object that Crust then maps to.
    func createObject(type: BaseType.Type) throws -> BaseType
    
    /// Delete an object.
    func deleteObject(_ obj: BaseType) throws
    
    /// Save a set of mapped objects. Called right before `mappingDidEnd`.
    func save(objects: [ BaseType ]) throws
}

public protocol Transform: AnyMapping {
    associatedtype MappingKeyType = RootKey
    
    func fromJSON(_ json: JSONValue) throws -> MappedObject
    func toJSON(_ obj: MappedObject) -> JSONValue
}

public extension Transform {
    func mapping(toMap: inout MappedObject, payload: MappingPayload<RootKey>) {
        switch payload.dir {
        case .fromJSON:
            do {
                try toMap = self.fromJSON(payload.json)
            } catch let err as NSError {
                payload.error = err
            }
        case .toJSON:
            payload.json = self.toJSON(toMap)
        }
    }
}

