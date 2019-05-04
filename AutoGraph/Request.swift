import Foundation
import JSONValueRX

/// A `Request` to be sent by AutoGraph.
public protocol Request {
    /// The returned type for the request.
    associatedtype SerializedObject: Decodable
    
    associatedtype QueryDocument: GraphQLDocument
    associatedtype Variables: GraphQLVariables
    
    /// The query to be sent to GraphQL.
    var queryDocument: QueryDocument { get }
    
    /// The variables sent along with the query.
    var variables: Variables? { get }
    
    /// The key path to the result object in the data
    var rootKeyPath: String { get }
    
    /// Called at the moment before the request will be sent from the `Client`.
    func willSend() throws
    
    /// Called as soon as the http request finishs.
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws
    
    /// Called right before calling the completion handler for the sent request, i.e. at the end of the lifecycle.
    func didFinish(result: AutoGraphResult<SerializedObject>) throws
}

/// A weird enum that collects info for a request.
public enum ObjectBinding<SerializedObject: Decodable> {
    case object(keyPath: String, completion: RequestCompletion<SerializedObject>)
}

extension Request {
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<SerializedObject> {
        return ObjectBinding<SerializedObject>.object(keyPath: self.rootKeyPath, completion: completion)
    }
}
