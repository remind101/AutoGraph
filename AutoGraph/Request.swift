import Crust
import Foundation
import JSONValueRX

/// A `Request` to be sent by AutoGraph.
public protocol Request {
    /// The `Mapping` used to map from the returned JSON payload to a concrete type
    /// `Mapping.MappedObject`.
    associatedtype Mapping: Crust.Mapping
    
    /// The root key into the JSON payload. E.g. If the payload has `[ "data" : [ stuff_I_want ] ]` the `RootKey`
    /// will be a `String` and the instance will be `"data"`.
    associatedtype RootKey: MappingKey
    
    /// The keys we'll use to map data out of the JSON payload. This payload starts from the JSON retreived from the root key in `mapping`.
    associatedtype MappingKeys: KeyCollection
    
    /// The returned type for the request.
    /// E.g if the requests returns an array then change to `[Mapping.MappedObject]`.
    associatedtype SerializedObject = Mapping.MappedObject
    
    associatedtype Query: GraphQLQuery
    associatedtype Variables: GraphQLVariables
    
    /// If the `SerializedObject`(s) cannot be passed across threads, then we'll use this to transform
    /// the objects as they are passed from the background to the main thread.
    associatedtype ThreadAdapterType: ThreadAdapter
    
    /// The query to be sent to GraphQL.
    var query: Query { get }
    
    /// The variables sent along with the query.
    var variables: Variables? { get }
    
    /// The mapping to use when mapping JSON into the a concrete type.
    ///
    /// **WARNING:**
    ///
    /// `mapping` does NOT execute on the main thread. It's important that any `Adapter`
    /// used by `mapping` establishes its own connection to the DB from within `mapping`.
    ///
    /// Additionally, the mapped data (`Mapping.MappedObject`) is assumed to be safe to pass
    /// across threads unless it inherits from `ThreadUnsafe`.
    var mapping: Binding<RootKey, Mapping> { get }
    
    // TODO: Use associatedtype where clauses in Swift 4.
    /// The collection of keys / fields that will be mapped from the query for this request.
    ///
    /// `MappingKeys.MappingKeyType` must equal `Mapping.MappingKeyType` or an "ambiguous reference" error will be thrown by the compiler when trying to send.
    var mappingKeys: MappingKeys { get }
    
    /// Our `ThreadAdapter`. Its `typealias BaseType` must be a the same type or a super type of `Mapping.MappedObject`
    /// or an error will be thrown at runtime.
    var threadAdapter: ThreadAdapterType? { get }
    
    /// Called at the moment before the request will be sent from the `Client`.
    func willSend() throws
    
    /// Called as soon as the http request finishs.
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws
    
    /// Called right before calling the completion handler for the sent request, i.e. at the end of the lifecycle.
    func didFinish(result: AutoGraphQL.Result<SerializedObject>) throws
}

/// A `Request` where the result objects can safely be transmitted across threads without special handling.
/// In other words, as soon as the result objects are generated from resolving the GraphQL response in the background
/// they are passed directly to the main thread and returned to the caller.
public protocol ThreadUnconfinedRequest: Request { }
public extension ThreadUnconfinedRequest {
    var threadAdapter: UnsafeThreadAdapter<Self.Mapping.MappedObject>? { return nil }
}

extension Int: AnyMappable { }
class VoidMapping<Key: MappingKey>: AnyMapping {
    typealias AdapterKind = AnyAdapterImp<MappedObject>
    typealias MappedObject = Int
    func mapping(toMap: inout Int, payload: MappingPayload<Key>) { }
}

/// Before returning `Result` to the caller, the `ThreadAdapter` passes our `ThreadSafeRepresentation`
/// back to the main thread and then uses `retrieveObjects(for:)` to return our result to the caller.
public protocol ThreadAdapter {
    associatedtype BaseType
    associatedtype CollectionType: RangeReplaceableCollection = [BaseType]
    associatedtype ThreadSafeRepresentation
    
    func threadSafeRepresentations(`for` objects: CollectionType, ofType type: Any.Type) throws -> [ThreadSafeRepresentation]
    func retrieveObjects(`for` representations: [ThreadSafeRepresentation]) throws -> CollectionType
}

/// Use this as your thread adapter if you prefer to ignore thread safety. This simply returns the objects passed into it.
/// You may also use this to generate a no-op - `var threadAdapter: UnsafeThreadAdapter<Self.Mapping.MappedObject>? { return nil }`.
public class UnsafeThreadAdapter<T>: ThreadAdapter {
    public typealias BaseType = T

    public func threadSafeRepresentations(`for` objects: [T], ofType type: Any.Type) throws -> [T] {
        return objects
    }
    
    public func retrieveObjects(`for` representations: [T]) throws -> [T] {
        return representations
    }
}

// TODO: We should support non-equatable collections.
// TOOD: We should better apply currying and futures to clean some of this up.
public enum ObjectBinding<K: MappingKey, M: Mapping, CM: Mapping, KC: KeyCollection, C: RangeReplaceableCollection,
    T: ThreadAdapter>
where C.Iterator.Element == CM.MappedObject, CM.MappedObject: Equatable, M.MappingKeyType == KC.MappingKeyType, CM.MappingKeyType == KC.MappingKeyType {
    
    case object(mappingBinding: () -> Binding<K, M>, threadAdapter: T?, mappingKeys: KC, completion: RequestCompletion<M.MappedObject>)
    case collection(mappingBinding: () -> Binding<K, CM>, threadAdapter: T?, mappingKeys: KC, completion: RequestCompletion<C>)
}

extension Request
    where SerializedObject: RangeReplaceableCollection,
    SerializedObject.Iterator.Element == Mapping.MappedObject,
    Mapping.MappedObject: Equatable,
    Mapping.MappingKeyType == MappingKeys.MappingKeyType {
    
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<RootKey, Mapping, Mapping, MappingKeys, SerializedObject, ThreadAdapterType> {
        return ObjectBinding<RootKey, Mapping, Mapping, MappingKeys, SerializedObject, ThreadAdapterType>.collection(mappingBinding: { self.mapping }, threadAdapter: self.threadAdapter, mappingKeys: self.mappingKeys, completion: completion)
    }
}

extension Request where SerializedObject == Mapping.MappedObject, Mapping.MappingKeyType == MappingKeys.MappingKeyType {
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<RootKey, Mapping, VoidMapping<Mapping.MappingKeyType>, MappingKeys, Array<Int>, ThreadAdapterType> {
        return ObjectBinding<RootKey, Mapping, VoidMapping<Mapping.MappingKeyType>, MappingKeys, Array<Int>, ThreadAdapterType>.object(mappingBinding: { self.mapping }, threadAdapter: threadAdapter, mappingKeys: self.mappingKeys, completion: completion)
    }
}
