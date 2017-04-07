import Crust
import Foundation
import JSONValueRX

/// A `Request` to be sent by AutoGraph.
public protocol Request {
    /// The `Mapping` used to map from the returned JSON payload to a concrete type
    /// `Mapping.MappedObject`.
    associatedtype Mapping: Crust.Mapping
    
    /// The returned type for the request.
    /// E.g if the requests returns an array then change to `[Mapping.MappedObject]`.
    associatedtype SerializedObject = Mapping.MappedObject
    
    associatedtype Query: GraphQLQuery
    
    /// If the `SerializedObject`(s) cannot be passed across threads, then we'll use this to transform
    /// the objects as they are passed from the background to the main thread.
    associatedtype ThreadAdapterType: ThreadAdapter
    
    /// The query to be sent to GraphQL.
    var query: Query { get }
    
    /// The mapping to use when mapping JSON into the a concrete type.
    ///
    /// **WARNING:**
    ///
    /// `mapping` does NOT execute on the main thread. It's important that any `Adapter`
    /// used by `mapping` establishes its own connection to the DB from within `mapping`.
    ///
    /// Additionally, the mapped data (`Mapping.MappedObject`) is assumed to be safe to pass
    /// across threads unless it inherits from `ThreadUnsafe`.
    var mapping: Binding<Mapping> { get }
    
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
class VoidMapping: AnyMapping {
    typealias AdapterKind = AnyAdapterImp<MappedObject>
    typealias MappedObject = Int
    func mapping(toMap: inout Int, context: MappingContext) { }
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
public enum ObjectBinding<M: Mapping, CM: Mapping, C: RangeReplaceableCollection,
    T: ThreadAdapter>
where C.Iterator.Element == CM.MappedObject, CM.MappedObject: Equatable {
    
    case object(mappingBinding: () -> Binding<M>, threadAdapter: T?, completion: RequestCompletion<M.MappedObject>)
    case collection(mappingBinding: () -> Binding<CM>, threadAdapter: T?, completion: RequestCompletion<C>)
}

extension Request
    where SerializedObject: RangeReplaceableCollection,
    SerializedObject.Iterator.Element == Mapping.MappedObject,
    Mapping.MappedObject: Equatable {
    
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<Mapping, Mapping, SerializedObject, ThreadAdapterType> {
        return ObjectBinding<Mapping, Mapping, SerializedObject, ThreadAdapterType>.collection(mappingBinding: { self.mapping }, threadAdapter: self.threadAdapter, completion: completion)
    }
}

extension Request where SerializedObject == Mapping.MappedObject {
    func generateBinding(completion: @escaping RequestCompletion<Mapping.MappedObject>) -> ObjectBinding<Mapping, VoidMapping, Array<Int>, ThreadAdapterType> {
        return ObjectBinding<Mapping, VoidMapping, Array<Int>, ThreadAdapterType>.object(mappingBinding: { self.mapping }, threadAdapter: threadAdapter, completion: completion)
    }
}
