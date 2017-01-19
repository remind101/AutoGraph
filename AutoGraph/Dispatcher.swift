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
    
    internal typealias Sendable = (query: Operation, completion: (DataResponse<Any>) -> ())
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
    
    public func send<T: Request, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>
        (request: T, completion: @escaping RequestCompletion<T.Mapping>)
        where T.Mapping: ArrayMapping<SubType, SubAdaptor, SubMapping>,
        SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType, SubType: ThreadUnsafe {
    
        let sendable: Sendable = (query: request.query, completion: { [weak self] response in
            self?.responseHandler.handle(response: response, mapping: { request.mapping }, completion: completion)
        })
        
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        self.send(sendable: sendable)
    }
    
    public func send<T: Request>(request: T, completion: @escaping RequestCompletion<T.Mapping>) {
        
        let sendable: Sendable = (query: request.query, completion: { [weak self] response in
            self?.responseHandler.handle(response: response, mapping: { request.mapping }, completion: completion)
        })
        
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        self.send(sendable: sendable)
    }
    
    func send(sendable: Sendable) {
        self.requestSender.sendRequest(url: self.url, parameters: ["query" : sendable.query.graphQLString], completion: sendable.completion)
    }
    
    func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
