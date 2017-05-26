import Alamofire
import Crust
import Foundation
import JSONValueRX

public class ResponseHandler {
    
    private let queue: OperationQueue
    private let callbackQueue: OperationQueue
    public var networkErrorParser: NetworkErrorParser?
    
    init(queue: OperationQueue = OperationQueue(),
         callbackQueue: OperationQueue = OperationQueue.main) {
        
        self.queue = queue
        self.callbackQueue = callbackQueue
    }
    
    func handle<M: Mapping, CM: Mapping, C: RangeReplaceableCollection, T: ThreadAdapter>(
        response: DataResponse<Any>,
        objectBinding: ObjectBinding<M, CM, C, T>,
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
    
    private func map<M: Mapping, CM: Mapping, C: RangeReplaceableCollection, T: ThreadAdapter>(
        json: JSONValue,
        objectBinding: ObjectBinding<M, CM, C, T>) {
            
            do {
                switch objectBinding {
                case .object(let binding, let threadAdapter, let completion):
                    let mapper = Mapper()
                    let result: M.MappedObject = try mapper.map(from: json, using: binding())
                    
                    if let threadAdapter = threadAdapter {
                        self.refetchAndComplete(result: result, json: json, mapping: binding, threadAdapter: threadAdapter, completion: completion)
                    }
                    else {
                        self.callbackQueue.addOperation {
                            completion(.success(result))
                        }
                    }
                    
                case .collection(let binding, let threadAdapter, let completion):
                    let mapper = Mapper()
                    let result: C = try mapper.map(from: json, using: binding())
                    
                    if let threadAdapter = threadAdapter {
                        self.refetchAndComplete(result: result, json: json, mapping: binding, threadAdapter: threadAdapter, completion: completion)
                    }
                    else {
                        self.callbackQueue.addOperation {
                            completion(.success(result))
                        }
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
    
    func fail<M: Mapping, CM: Mapping, C: RangeReplaceableCollection, T: ThreadAdapter>(error: Error, objectBinding: ObjectBinding<M, CM, C, T>) {
        switch objectBinding {
        case .object(mappingBinding: _, threadAdapter: _, completion: let completion):
            self.fail(error: error, completion: completion)
        case .collection(mappingBinding: _, threadAdapter: _, completion: let completion):
            self.fail(error: error, completion: completion)
        }
    }

    private func refetchAndComplete<Mapping: Crust.Mapping, Result, T: ThreadAdapter>
        (result: Result,
         json: JSONValue,
         mapping: @escaping () -> Binding<Mapping>,
         threadAdapter: T,
         completion: @escaping RequestCompletion<Result>)
        where Result == Mapping.MappedObject {
        
            do {
                let threadAdapterResult = try coerceToType(result) as T.CollectionType.Iterator.Element
                let collection = T.CollectionType([threadAdapterResult])
                let representation = try threadAdapter.threadSafeRepresentations(for: collection, ofType: Result.self)
                self.callbackQueue.addOperation { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    do {
                        let objects = try threadAdapter.retrieveObjects(for: representation)
                        completion(.success(try strongSelf.coerceToType(objects.first)))
                    }
                    catch let e {
                        strongSelf.fail(error: AutoGraphError.refetching(error: e), completion: completion)
                    }
                }
            }
            catch let e {
                self.callbackQueue.addOperation {
                    self.fail(error: AutoGraphError.refetching(error: e), completion: completion)
                }
            }
    }
    
    private func refetchAndComplete<Mapping: Crust.Mapping, Result: RangeReplaceableCollection, T: ThreadAdapter>
        (result: Result,
         json: JSONValue,
         mapping: @escaping () -> Binding<Mapping>,
         threadAdapter: T,
         completion: @escaping RequestCompletion<Result>)
        where Result.Iterator.Element == Mapping.MappedObject, Mapping.MappedObject: Equatable {
        
            do {
                let representation = try threadAdapter.threadSafeRepresentations(for: try coerceToType(result) as T.CollectionType, ofType: Result.self)
                self.callbackQueue.addOperation { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    do {
                        let objects = try threadAdapter.retrieveObjects(for: representation)
                        completion(.success(try strongSelf.coerceToType(objects)))
                    }
                    catch let e {
                        strongSelf.fail(error: AutoGraphError.refetching(error: e), completion: completion)
                    }
                }
            }
            catch let e {
                self.callbackQueue.addOperation {
                    self.fail(error: AutoGraphError.refetching(error: e), completion: completion)
                }
            }
    }
    
    internal func coerceToType<T, U>(_ instance: T) throws -> U {
        guard case let coerced as U = instance else {
            throw AutoGraphError.typeCoercion(from: T.self, to: U.self)
        }
        return coerced
    }
}
