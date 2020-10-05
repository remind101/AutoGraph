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
    
    /// The Operation Name for the query document.
    var operationName: String { get }
    
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

extension Request where QueryDocument == Operation {
    public var operationName: String {
        return self.queryDocument.name
    }
}

/// A weird enum that collects info for a request.
public enum ObjectBinding<SerializedObject: Decodable> {
    case object(keyPath: String, isRequestIncludingNetworkResponse: Bool, completion: RequestCompletion<SerializedObject>)
}

extension Request {
    func generateBinding(completion: @escaping RequestCompletion<SerializedObject>) -> ObjectBinding<SerializedObject> {
        return ObjectBinding<SerializedObject>.object(keyPath: self.rootKeyPath, isRequestIncludingNetworkResponse: self is IsRequestIncludingNetworking, completion: completion)
    }
}

private protocol IsRequestIncludingNetworking {}
extension RequestIncludingNetworkResponse: IsRequestIncludingNetworking {}

public struct HTTPResponse: Decodable {
    public let urlString: String
    public let statusCode: Int
    public let headerFields: [String : String]
}

public struct DataIncludingNetworkResponse<T: Decodable>: Decodable {
    public let value: T
    public let json: JSONValue
    public let httpResponse: HTTPResponse?
}

public struct RequestIncludingNetworkResponse<R: Request>: Request {
    public typealias SerializedObject = DataIncludingNetworkResponse<R.SerializedObject>
    public typealias QueryDocument = R.QueryDocument
    public typealias Variables = R.Variables
    
    public let request: R
    
    public var queryDocument: R.QueryDocument {
        return self.request.queryDocument
    }
    
    public var operationName: String {
        return self.request.operationName
    }
    
    public var variables: R.Variables? {
        return self.request.variables
    }
    
    public var rootKeyPath: String {
        return self.request.rootKeyPath
    }
    
    public func willSend() throws {
        try self.request.willSend()
    }
    
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws {
        try self.request.didFinishRequest(response: response, json: json)
    }
    
    public func didFinish(result: Result<DataIncludingNetworkResponse<R.SerializedObject>, Error>) throws {
        try self.request.didFinish(result: {
            switch result {
            case .success(let data):
                return .success(data.value)
            case .failure(let error):
                return .failure(error)
            }
        }())
    }
}
