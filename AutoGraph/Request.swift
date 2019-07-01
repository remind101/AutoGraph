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
    case object(keyPath: String, isRequestIncludingJSON: Bool, completion: RequestCompletion<SerializedObject>)
}

extension Request {
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<SerializedObject> {
        return ObjectBinding<SerializedObject>.object(keyPath: self.rootKeyPath, isRequestIncludingJSON: self is IsRequestIncludingJSON, completion: completion)
    }
}

private protocol IsRequestIncludingJSON {}
extension RequestIncludingJSON: IsRequestIncludingJSON {}

public struct DataIncludingJSON<T: Decodable>: Decodable {
    public let value: T
    public let json: JSONValue
}

public struct RequestIncludingJSON<R: Request>: Request {
    public typealias SerializedObject = DataIncludingJSON<R.SerializedObject>
    public typealias QueryDocument = R.QueryDocument
    public typealias Variables = R.Variables
    
    public let request: R
    
    public var queryDocument: R.QueryDocument {
        return request.queryDocument
    }
    
    public var variables: R.Variables? {
        return request.variables
    }
    
    public var rootKeyPath: String {
        return request.rootKeyPath
    }
    
    public func willSend() throws {
        try request.willSend()
    }
    
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws {
        try request.didFinishRequest(response: response, json: json)
    }
    
    public func didFinish(result: Result<DataIncludingJSON<R.SerializedObject>, Error>) throws {
        try request.didFinish(result: {
            switch result {
            case .success(let data):
                return .success(data.value)
            case .failure(let error):
                return .failure(error)
            }
        }())
    }
}
