import Crust
import Foundation
import JSONValueRX

public protocol Request {
    /// The `Mapping` used to map from the returned JSON payload to a concrete type
    /// `Mapping.MappedObject`.
    associatedtype Mapping: Crust.Mapping
    
    /// The returned type for the request.
    /// E.g if the requests returns an array then change to `[Mapping.MappedObject]`.
    associatedtype SerializedObject = Mapping.MappedObject
    
    associatedtype Query: GraphQLQuery
    
    /// The query to be sent to GraphQL.
    var query: Query { get }
    
    /// The mapping to use when mapping JSON into the a concrete type.
    ///
    /// **WARNING:**
    ///
    /// `mapping` does NOT execute on the main thread. It's important that any `Adapter`
    /// used by `mapping` establishes it's own connection to the DB from within `mapping`.
    ///
    /// Additionally, the mapped data (`Mapping.MappedObject`) is assumed to be safe to pass
    /// across threads unless it inherits from `ThreadUnsafe`.
    var mapping: Binding<Mapping> { get }
    
    /// Called at the moment before the request will be sent from the `Client`.
    func willSend() throws
    
    /// Called as soon as the http request finishs.
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws
    
    /// Called right before calling the completion handler for the sent request, i.e. at the end of the lifecycle.
    func didFinish(result: AutoGraphQL.Result<SerializedObject>) throws
}

extension Int: AnyMappable { }
class VoidMapping: AnyMapping {
    typealias AdapterKind = AnyAdapterImp<MappedObject>
    typealias MappedObject = Int
    func mapping(tomap: inout Int, context: MappingContext) { }
}

// TODO: We should support non-equatable collections.
// TOOD: We should better apply currying and futures to clean some of this up.
public enum ObjectBinding<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>
where C.Iterator.Element == CM.MappedObject, CM.MappedObject: Equatable {
    
    case object(mappingBinding: () -> Binding<M>, completion: RequestCompletion<M.MappedObject>)
    case collection(mappingBinding: () -> Binding<CM>, completion: RequestCompletion<C>)
}

extension Request
    where SerializedObject: RangeReplaceableCollection,
    SerializedObject.Iterator.Element == Mapping.MappedObject,
    Mapping.MappedObject: Equatable {
    
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<Mapping, Mapping, SerializedObject> {
        return ObjectBinding<Mapping, Mapping, SerializedObject>.collection(mappingBinding: { self.mapping }, completion: completion)
    }
}

extension Request where SerializedObject == Mapping.MappedObject {
    func generateBinding(completion: @escaping RequestCompletion<Mapping.MappedObject>) -> ObjectBinding<Mapping, VoidMapping, Array<Int>> {
        return ObjectBinding<Mapping, VoidMapping, Array<Int>>.object(mappingBinding: { self.mapping }, completion: completion)
    }
}
