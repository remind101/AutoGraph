import Alamofire
import Crust
import Foundation

public protocol RequestSender {
    func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ())
}

public final class Sendable {
    public let query: GraphQLQuery
    public let variables: GraphQLVariables?
    public let willSend: (() throws -> ())?
    public let dispatcherCompletion: (Sendable) -> (DataResponse<Any>) -> ()
    public let dispatcherEarlyFailure: (Sendable) -> (Error) -> ()
    
    public required init(query: GraphQLQuery, variables: GraphQLVariables?, willSend: (() throws -> ())?, dispatcherCompletion: @escaping (Sendable) -> (DataResponse<Any>) -> (), dispatcherEarlyFailure: @escaping (Sendable) -> (Error) -> ()) {
        self.query = query
        self.variables = variables
        self.willSend = willSend
        self.dispatcherCompletion = dispatcherCompletion
        self.dispatcherEarlyFailure = dispatcherEarlyFailure
    }
    
    public convenience init<R: Request, K: MappingKey, M: Mapping, CM: Mapping, KC: KeyCollection, C: RangeReplaceableCollection, T: ThreadAdapter>
        (dispatcher: Dispatcher, request: R, objectBindingPromise: @escaping (Sendable) -> ObjectBinding<K, M, CM, KC, C, T>, globalWillSend: ((R) throws -> ())?) {
        
        let completion: (Sendable) -> (DataResponse<Any>) -> () = { [weak dispatcher] sendable in
            { [weak dispatcher] response in
                dispatcher?.responseHandler.handle(response: response, objectBinding: objectBindingPromise(sendable), preMappingHook: request.didFinishRequest)
            }
        }
        
        let earlyFailure: (Sendable) -> (Error) -> () = { [weak dispatcher] sendable in
            { [weak dispatcher] e in
                dispatcher?.responseHandler.fail(error: e, objectBinding: objectBindingPromise(sendable))
            }
        }
        
        let willSend: (() throws -> ())? = {
            try globalWillSend?(request)
            try request.willSend()
        }
        
        self.init(query: request.query, variables: request.variables, willSend: willSend, dispatcherCompletion: completion, dispatcherEarlyFailure: earlyFailure)
    }
}

public class Dispatcher {
        
    public let url: String
    public let responseHandler: ResponseHandler
    public let requestSender: RequestSender
    
    public internal(set) var pendingRequests = [Sendable]()
    
    public internal(set) var paused = false {
        didSet {
            if !self.paused {
                self.pendingRequests.forEach { sendable in
                    self.send(sendable: sendable)
                }
                self.pendingRequests.removeAll()
            }
        }
    }
    
    public required init(url: String, requestSender: RequestSender, responseHandler: ResponseHandler) {
        self.url = url
        self.requestSender = requestSender
        self.responseHandler = responseHandler
    }
    
    open func send(sendable: Sendable) {
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        do {
            try sendable.willSend?()
            let query = try sendable.query.graphQLString()
            var parameters: [String : Any] = ["query" : query]
            if let variables = try sendable.variables?.graphQLVariablesDictionary() {
                parameters["variables"] = variables
            }
            self.requestSender.sendRequest(url: self.url, parameters: parameters, completion: sendable.dispatcherCompletion(sendable))
        }
        catch let e {
            sendable.dispatcherEarlyFailure(sendable)(e)
        }
    }
    
    open func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
