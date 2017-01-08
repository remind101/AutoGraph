import Alamofire
import Crust
import Foundation

protocol DispatcherDelegate: class {
    func dispatcherDidFinish<Mapping: Crust.Mapping>(
        response: DataResponse<Any>,
        mapping: Mapping,
        completion: @escaping RequestCompletion<Mapping>)
}

class Dispatcher {
    
    var url: String
    
    weak var delegate: DispatcherDelegate?
    
    internal typealias Sendable = (query: Operation, completion: (DataResponse<Any>) -> ())
    internal(set) var pendingRequests = [ Sendable ]()
    
    internal var paused = false {
        didSet {
            if !self.paused {
                self.pendingRequests.forEach { sendable in
                    self.send(sendable: sendable)
                }
            }
        }
    }
    
    init(url: String) {
        self.url = url
    }
    
    public func send<T: Request>(request: T, completion: @escaping RequestCompletion<T.Mapping>) {
        
        let sendable: Sendable = (query: request.query, completion: { response in
            
            self.delegate?.dispatcherDidFinish(response: response, mapping: request.mapping, completion: completion)
        })
        
        guard !self.paused else {
            self.pendingRequests.append(sendable)
            return
        }
        
        self.send(sendable: sendable)
    }
    
    func send(sendable: Sendable) {
        Alamofire.request(self.url, parameters: ["query" : sendable.query.graphQLString]).responseJSON(completionHandler: sendable.completion)
    }
    
    func cancelAll() {
        self.pendingRequests.removeAll()
    }
}
