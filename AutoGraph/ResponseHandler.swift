import Alamofire
import Crust
import Foundation
import JSONValueRX

class ResponseHandler {
    
    private let queue: OperationQueue
    private let callbackQueue: OperationQueue
    
    init(queue: OperationQueue = OperationQueue(),
         callbackQueue: OperationQueue = OperationQueue.main) {
        
        self.queue = queue
        self.callbackQueue = callbackQueue
    }
    
    func handle<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(
        response: DataResponse<Any>,
        resultSpec: ResultSpec<M, CM, C>) {
            
            do {
                let value = try response.extractValue()
                let json = try JSONValue(object: value)
                
                if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                    throw queryError
                }
                
                self.queue.addOperation { [weak self] in
                    self?.map(json: json, resultSpec: resultSpec)
                }
            }
            catch let e {
                self.fail(error: e, resultSpec: resultSpec)
            }
    }
    
    private func map<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(
        json: JSONValue,
        resultSpec: ResultSpec<M, CM, C>) {
            
            do {
                switch resultSpec {
                case .object(let spec, let completion):
                    let mapper = Mapper()
                    let result: M.MappedObject = try mapper.map(from: json, using: spec())
                    
                    self.refetchAndComplete(result: result, json: json, mapping: spec, completion: completion)
                    
                case .collection(let spec, let completion):
                    let mapper = Mapper()
                    let result: C = try mapper.map(from: json, using: spec())
                    
                    self.refetchAndComplete(result: result, json: json, mapping: spec, completion: completion)
                }
            }
            catch let e {
                switch resultSpec {
                case .object(_, let completion):
                    self.fail(error: AutoGraphError.mapping(error: e), completion: completion)
                case .collection(_, let completion):
                    self.fail(error: AutoGraphError.mapping(error: e), completion: completion)
                }
            }
    }
    
    // MARK: - Post mapping.
    
    private func fail<R>(error: Error, completion: @escaping RequestCompletion<R>) {
        self.callbackQueue.addOperation {
            completion(.failure(error))
        }
    }
    
    private func fail<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(error: Error, resultSpec: ResultSpec<M, CM, C>) {
        switch resultSpec {
        case .object(mappingSpec: _, completion: let completion):
            self.fail(error: error, completion: completion)
        case .collection(mappingSpec: _, completion: let completion):
            self.fail(error: error, completion: completion)
        }
    }

    private func refetchAndComplete<Mapping: Crust.Mapping, Result>
        (result: Result,
         json: JSONValue,
         mapping: @escaping () -> Binding<Mapping>,
         completion: @escaping RequestCompletion<Result>)
        where Result == Mapping.MappedObject {
        
        guard case let unsafe as ThreadUnsafe = result else {
            self.callbackQueue.addOperation {
                completion(.success(result))
            }
            return
        }
        
        let primaryKey = type(of: unsafe).primaryKey()!
        let primaryKeys: [[String : CVarArg]] = {
            guard case let value as CVarArg = unsafe.value(forKeyPath: primaryKey) else {
                return []
            }
            return [[primaryKey : value]]
        }()
        
        self.callbackQueue.addOperation {
            let map = mapping().mapping
            guard case let finalResult as Result = map.adaptor.fetchObjects(type: Mapping.MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: primaryKeys, isMapping: false)?.first else {
                
                self.fail(error: AutoGraphError.refetching, completion: completion)
                return
            }
            completion(.success(finalResult))
        }
    }
    
    private func refetchAndComplete<Mapping: Crust.Mapping, Result: RangeReplaceableCollection>
        (result: Result,
         json: JSONValue,
         mapping: @escaping () -> Binding<Mapping>,
         completion: @escaping RequestCompletion<Result>)
        where Result.Iterator.Element == Mapping.MappedObject, Mapping.SequenceKind == Result, Mapping.MappedObject: Equatable {
    
        guard case let UnsafeType as ThreadUnsafe.Type = Mapping.MappedObject.self else {
            self.callbackQueue.addOperation {
                completion(.success(result))
            }
            return
        }
            
        let primaryKey = UnsafeType.primaryKey()!
            
        let primaryKeys: [[String : CVarArg]] = result.flatMap {
            guard case let value as CVarArg = ($0 as! ThreadUnsafe).value(forKeyPath: primaryKey) else {
                return nil
            }
            return [primaryKey : value]
        }
        
        self.callbackQueue.addOperation {
            let map = mapping().mapping
            guard let results = map.adaptor.fetchObjects(type: Mapping.MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: primaryKeys, isMapping: false) else {
                
                self.fail(error: AutoGraphError.refetching, completion: completion)
                return
            }
            let mappedResults = Result(results.map { $0 as! Mapping.MappedObject })
            completion(.success(mappedResults))
        }
    }
}
