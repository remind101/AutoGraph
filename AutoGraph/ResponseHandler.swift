import Alamofire
import Foundation
import JSONValueRX

open class ResponseHandler {
    
    private let queue: OperationQueue
    private let callbackQueue: OperationQueue
    public var networkErrorParser: NetworkErrorParser?
    
    public init(queue: OperationQueue = OperationQueue(),
                callbackQueue: OperationQueue = OperationQueue.main) {
        
        self.queue = queue
        self.callbackQueue = callbackQueue
    }
    
    func handle<SerializedObject: Codable>(response: DataResponse<Any>,
                                           preMappingHook: (HTTPURLResponse?, JSONValue) throws -> (),
                                           completion: @escaping RequestCompletion<SerializedObject>) {
            
            do {
                let json = try response.extractJSON(networkErrorParser: self.networkErrorParser ?? { _ in return nil })
                
                try preMappingHook(response.response, json)
                
                self.queue.addOperation { [weak self] in
                    self?.map(json: json, completion: completion)
                }
            }
            catch let e {
                completion(.failure(e))
            }
    }
    
    private func map<SerializedObject: Codable>(json: JSONValue, completion: @escaping RequestCompletion<SerializedObject>) {
            
            do {
                let decoder = JSONDecoder()
                let object = try decoder.decode(SerializedObject.self, from: json.encode())
                
                self.callbackQueue.addOperation {
                    completion(.success(object))
                }
            }
            catch let e {
                completion(.failure(AutoGraphError.mapping(error: e)))
            }
    }
    
    // MARK: - Post mapping.
    
    func fail<R>(error: Error, completion: @escaping RequestCompletion<R>) {
        self.callbackQueue.addOperation {
            completion(.failure(error))
        }
    }
}
