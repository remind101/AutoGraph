import Foundation
import JSONValueRX

/// A `Request` to be sent by AutoGraph.
public protocol Request {
    /// The returned type for the request.
    associatedtype SerializedObject: Codable
    
    associatedtype QueryDocument: GraphQLDocument
    associatedtype Variables: GraphQLVariables
    
    /// The query to be sent to GraphQL.
    var queryDocument: QueryDocument { get }
    
    /// The variables sent along with the query.
    var variables: Variables? { get }
    
    /// Called at the moment before the request will be sent from the `Client`.
    func willSend() throws
    
    /// Called as soon as the http request finishs.
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws
    
    /// Called right before calling the completion handler for the sent request, i.e. at the end of the lifecycle.
    func didFinish(result: AutoGraphQL.Result<SerializedObject>) throws
}

/// A weird enum that collects info for a request.
public enum ObjectBinding<SerializedObject: Codable> {
    case object(completion: RequestCompletion<SerializedObject>)
}

extension Request {
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<SerializedObject> {
        return ObjectBinding<SerializedObject>.object(completion: completion)
    }
}
