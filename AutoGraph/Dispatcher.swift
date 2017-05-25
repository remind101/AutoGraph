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
    public let completion: (DataResponse<Any>) -> ()
    public let earlyFailure: (Error) -> ()
    
    public required init(query: GraphQLQuery, variables: GraphQLVariables?, willSend: (() throws -> ())?, completion: @escaping (DataResponse<Any>) -> (), earlyFailure: @escaping (Error) -> ()) {
        self.query = query
        self.variables = variables
        self.willSend = willSend
        self.completion = completion
        self.earlyFailure = earlyFailure
    }
    
    public convenience init<R: Request, M: Mapping, CM: Mapping, C: RangeReplaceableCollection, T: ThreadAdapter>
        (dispatcher: Dispatcher, request: R, objectBinding: ObjectBinding<M, CM, C, T>, globalWillSend: ((R) throws -> ())?) {
        
        let completion: (DataResponse<Any>) -> () = { [weak dispatcher] response in
            dispatcher?.responseHandler.handle(response: response, objectBinding: objectBinding, preMappingHook: request.didFinishRequest)
        }
        
        let earlyFailure: (Error) -> () = { [weak dispatcher] e in
            dispatcher?.responseHandler.fail(error: e, objectBinding: objectBinding)
        }
        
        let willSend: (() throws -> ())? = {
            try globalWillSend?(request)
            try request.willSend()
        }
        
        self.init(query: request.query, variables: request.variables, willSend: willSend, completion: completion, earlyFailure: earlyFailure)
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
            self.requestSender.sendRequest(url: self.url, parameters: parameters, completion: sendable.completion)
        }
        catch let e {
            sendable.earlyFailure(e)
        }
    }
    
    open func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
