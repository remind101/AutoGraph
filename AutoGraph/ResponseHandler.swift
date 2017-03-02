import Alamofire
import Crust
import Foundation
import JSONValueRX

public class ResponseHandler {
    
    private let queue: OperationQueue
    private let callbackQueue: OperationQueue
    
    init(queue: OperationQueue = OperationQueue(),
         callbackQueue: OperationQueue = OperationQueue.main) {
        
        self.queue = queue
        self.callbackQueue = callbackQueue
    }
    
    func handle<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(
        response: DataResponse<Any>,
        objectBinding: ObjectBinding<M, CM, C>) {
            
            do {
                let value = try response.extractValue()
                let json = try JSONValue(object: value)
                
                if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                    throw queryError
                }
                
                self.queue.addOperation { [weak self] in
                    self?.map(json: json, objectBinding: objectBinding)
                }
            }
            catch let e {
                self.fail(error: e, objectBinding: objectBinding)
            }
    }
    
    private func map<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(
        json: JSONValue,
        objectBinding: ObjectBinding<M, CM, C>) {
            
            do {
                switch objectBinding {
                case .object(let binding, let completion):
                    let mapper = Mapper()
                    let result: M.MappedObject = try mapper.map(from: json, using: binding())
                    
                    self.refetchAndComplete(result: result, json: json, mapping: binding, completion: completion)
                    
                case .collection(let binding, let completion):
                    let mapper = Mapper()
                    let result: C = try mapper.map(from: json, using: binding())
                    
                    self.refetchAndComplete(result: result, json: json, mapping: binding, completion: completion)
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
    
    func fail<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(error: Error, objectBinding: ObjectBinding<M, CM, C>) {
        switch objectBinding {
        case .object(mappingBinding: _, completion: let completion):
            self.fail(error: error, completion: completion)
        case .collection(mappingBinding: _, completion: let completion):
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
        
        let primaryKeyValues = self.primaryKeyValues(for: unsafe)
        
        self.callbackQueue.addOperation {
            let map = mapping().mapping
            guard case let finalResult as Result = map.adaptor.fetchObjects(type: Mapping.MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: [primaryKeyValues], isMapping: false)?.first else {
                
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
        where Result.Iterator.Element == Mapping.MappedObject, Mapping.MappedObject: Equatable {
    
        guard
            case let unsafeResults as [ThreadUnsafe] = result
        else {
            self.callbackQueue.addOperation {
                completion(.success(result))
            }
            return
        }
        
        let primaryKeyValues: [[String : CVarArg]] = unsafeResults.flatMap { unsafe in
            self.primaryKeyValues(for: unsafe)
        }
        
        self.callbackQueue.addOperation {
            let map = mapping().mapping
            guard let results = map.adaptor.fetchObjects(type: Mapping.MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: primaryKeyValues, isMapping: false) else {
                
                self.fail(error: AutoGraphError.refetching, completion: completion)
                return
            }
            let mappedResults = Result(results.map { $0 as! Mapping.MappedObject })
            completion(.success(mappedResults))
        }
    }
    
    private func primaryKeyValues(for unsafe: ThreadUnsafe) -> [String : CVarArg] {
        let primaryKeys = type(of: unsafe).primaryKeys
        let primaryKeyValuePairs: [(String, CVarArg)] = primaryKeys.flatMap {
            guard case let value as CVarArg = unsafe.value(forKeyPath: $0) else {
                return nil
            }
            return ($0, value)
        }
        
        let primaryKeyValues: [String : CVarArg] = {
            var dict = [String : CVarArg]()
            primaryKeyValuePairs.forEach { dict[$0.0] = $0.1 }
            return dict
        }()
        
        return primaryKeyValues
    }
}
