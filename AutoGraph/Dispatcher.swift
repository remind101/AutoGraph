import Alamofire
import Crust
import Foundation

public protocol RequestSender {
    func sendRequest(url: String, parameters: [String : Any], completion: @escaping (DataResponse<Any>) -> ())
}

class Dispatcher {
        
    let url: String
    let responseHandler: ResponseHandler
    let requestSender: RequestSender
    
    internal typealias Sendable = (query: Operation, completion: (DataResponse<Any>) -> (), earlyFailure: (Error) -> ())
    internal(set) var pendingRequests = [ Sendable ]()
    
    internal var paused = false {
        didSet {
            if !self.paused {
                self.pendingRequests.forEach { sendable in
                    self.send(sendable: sendable)
                }
                self.pendingRequests.removeAll()
            }
        }
    }
    
    init(url: String, requestSender: RequestSender, responseHandler: ResponseHandler) {
        self.url = url
        self.requestSender = requestSender
        self.responseHandler = responseHandler
    }
    
    public func send<T: Request, M: Mapping, CM: Mapping, C: RangeReplaceableCollection>
    (request: T, resultBinding: ResultBinding<M, CM, C>) {
        
        let completion: (DataResponse<Any>) -> () = { [weak self] response in
            self?.responseHandler.handle(response: response, resultBinding: resultBinding)
        }
        
        let earlyFailure: (Error) -> () = { [weak self] e in
            self?.responseHandler.fail(error: e, resultBinding: resultBinding)
        }
        
        let sendable: Sendable = (query: request.query, completion: completion, earlyFailure: earlyFailure)
        
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        self.send(sendable: sendable)
    }
    
    func send(sendable: Sendable) {
        do {
            self.requestSender.sendRequest(url: self.url, parameters: ["query" : try sendable.query.graphQLString()], completion: sendable.completion)
        }
        catch let e {
            sendable.earlyFailure(e)
        }
    }
    
    func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
