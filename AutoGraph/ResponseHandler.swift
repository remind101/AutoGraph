import Alamofire
import Foundation
import JSONValueRX

open class ResponseHandler {
    
    public struct ObjectKeyPathError: LocalizedError {
        let keyPath: String
        public var errorDescription: String? {
            return "No object to map found at keyPath '\(self.keyPath)'"
        }
    }
    
    private let queue: OperationQueue
    private let callbackQueue: OperationQueue
    public var networkErrorParser: NetworkErrorParser?
    
    public init(queue: OperationQueue = OperationQueue(),
                callbackQueue: OperationQueue = OperationQueue.main) {
        self.queue = queue
        self.callbackQueue = callbackQueue
    }
    
    func handle<SerializedObject: Decodable>(response: DataResponse<Any>,
                                             objectBinding: ObjectBinding<SerializedObject>,
                                             preMappingHook: (HTTPURLResponse?, JSONValue) throws -> ()) {
            do {
                let json = try response.extractJSON(networkErrorParser: self.networkErrorParser ?? { _ in return nil })
                try preMappingHook(response.response, json)
                
                self.queue.addOperation { [weak self] in
                    self?.map(json: json, objectBinding: objectBinding)
                }
            }
            catch let e {
                self.fail(error: e, objectBinding: objectBinding)
            }
    }
    
    private func map<SerializedObject: Decodable>(json: JSONValue, objectBinding: ObjectBinding<SerializedObject>) {
            do {
                switch objectBinding {
                case .object(let keyPath, let isRequestIncludingJSON, let completion):
                    let decoder = JSONDecoder()
                    let decodingJSON: JSONValue = try {
                        guard let objectJson = json[keyPath] else {
                            throw ObjectKeyPathError(keyPath: keyPath)
                        }
                        
                        switch isRequestIncludingJSON {
                        case true:  return .object(["json" : objectJson, "value" : objectJson])
                        case false: return objectJson
                        }
                    }()
                    let object = try decoder.decode(SerializedObject.self, from: decodingJSON.encode())
                    
                    self.callbackQueue.addOperation {
                        completion(.success(object))
                    }
                }
            }
            catch let e {
                self.fail(error: AutoGraphError.mapping(error: e), objectBinding: objectBinding)
            }
    }
    
    // MARK: - Post mapping.
    
    func fail<R>(error: Error, completion: @escaping RequestCompletion<R>) {
        self.callbackQueue.addOperation {
            completion(.failure(error))
        }
    }
    
    func fail<SerializedObject>(error: Error, objectBinding: ObjectBinding<SerializedObject>) {
        switch objectBinding {
        case .object(_, _, completion: let completion):
            self.fail(error: error, completion: completion)
        }
    }
}
