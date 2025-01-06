import Alamofire
import Foundation

public protocol RequestSender {
    func sendRequest(parameters: [String : Any], completion: @escaping (AFDataResponse<Any>) -> ())
}

public final class Sendable {
    public let queryDocument: GraphQLDocument
    public let variables: GraphQLVariables?
    public let willSend: (() throws -> ())?
    public let dispatcherCompletion: (Sendable) -> (AFDataResponse<Any>) -> ()
    public let dispatcherEarlyFailure: (Sendable) -> (Error) -> ()
    
    public required init(queryDocument: GraphQLDocument, variables: GraphQLVariables?, willSend: (() throws -> ())?, dispatcherCompletion: @escaping (Sendable) -> (AFDataResponse<Any>) -> (), dispatcherEarlyFailure: @escaping (Sendable) -> (Error) -> ()) {
        self.queryDocument = queryDocument
        self.variables = variables
        self.willSend = willSend
        self.dispatcherCompletion = dispatcherCompletion
        self.dispatcherEarlyFailure = dispatcherEarlyFailure
    }
    
    public convenience init<R :Request>(dispatcher: Dispatcher, request: R, objectBindingPromise: @escaping (Sendable) -> ObjectBinding<R.SerializedObject>, globalWillSend: ((R) throws -> ())?) {
        
        let completion: (Sendable) -> (AFDataResponse<Any>) -> () = { [weak dispatcher] sendable in
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
        
        self.init(queryDocument: request.queryDocument, variables: request.variables, willSend: willSend, dispatcherCompletion: completion, dispatcherEarlyFailure: earlyFailure)
    }
}

open class Dispatcher {
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
    
    public required init(requestSender: RequestSender, responseHandler: ResponseHandler) {
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
            let query = try sendable.queryDocument.graphQLString()
            var parameters: [String : Any] = ["query" : query]
            if let variables = try sendable.variables?.graphQLVariablesDictionary() {
                parameters["variables"] = variables
            }

            if let operation = sendable.queryDocument as? Operation {
                parameters["operationName"] = operation.name
            }
            else if let document = sendable.queryDocument as? Document, let operation = document.operations.first {
                parameters["operationName"] = operation.name
            }
            
            self.requestSender.sendRequest(parameters: parameters, completion: sendable.dispatcherCompletion(sendable))
        }
        catch let e {
            sendable.dispatcherEarlyFailure(sendable)(e)
        }
    }
    
    open func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
