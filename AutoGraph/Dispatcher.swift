import Alamofire
import Crust
import Foundation

public protocol RequestSender {
    func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ())
}

public class Dispatcher {
        
    public let url: String
    public let responseHandler: ResponseHandler
    public let requestSender: RequestSender
    
    public typealias Sendable = (query: GraphQLQuery, willSend: (() throws -> ())?, completion: (DataResponse<Any>) -> (), earlyFailure: (Error) -> ())
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
    
    func send<R: Request, M: Mapping, CM: Mapping, C: RangeReplaceableCollection>
    (request: R, objectBinding: ObjectBinding<M, CM, C>, globalWillSend: ((R) throws -> ())?) {
        
        let completion: (DataResponse<Any>) -> () = { [weak self] response in
            self?.responseHandler.handle(response: response, objectBinding: objectBinding)
        }
        
        let earlyFailure: (Error) -> () = { [weak self] e in
            self?.responseHandler.fail(error: e, objectBinding: objectBinding)
        }
        
        let willSend: (() throws -> ())? = {
            try globalWillSend?(request)
            try request.willSend()
        }
        
        let sendable: Sendable = (query: request.query, willSend: willSend, completion: completion, earlyFailure: earlyFailure)
        
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        self.send(sendable: sendable)
    }
    
    open func send(sendable: Sendable) {
        do {
            try sendable.willSend?()
            self.requestSender.sendRequest(url: self.url, parameters: ["query" : try sendable.query.graphQLString()], completion: sendable.completion)
        }
        catch let e {
            sendable.earlyFailure(e)
        }
    }
    
    open func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
