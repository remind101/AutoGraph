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
    
    func handle<M: Crust.ArrayMapping<SubType, SubAdaptor, SubMapping>, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>
        (response: DataResponse<Any>,
         mapping: @escaping () -> M,
         completion: @escaping RequestCompletion<M>)
        where SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType, SubType: ThreadUnsafe {
        
        do {
            let value = try response.extractValue()
            let json = try JSONValue(object: value)
            
            if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                throw queryError
            }
            
            self.queue.addOperation { [weak self] in
                self?.map(json: json, mapping: mapping, completion: completion)
            }
        }
        catch let e {
            self.fail(error: e, mapping: mapping, completion: completion)
        }
    }
    
    func handle<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe>(response: DataResponse<Any>, mapping: @escaping () -> Mapping, completion: @escaping RequestCompletion<Mapping>) where Mapping.MappedObject == MappedObject {
        
        do {
            let value = try response.extractValue()
            let json = try JSONValue(object: value)
            
            if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                throw queryError
            }
            
            self.queue.addOperation { [weak self] in
                self?.map(json: json, mapping: mapping, completion: completion)
            }
        }
        catch let e {
            self.fail(error: e, mapping: mapping, completion: completion)
        }
    }
    
    func handle<Mapping: Crust.Mapping>(response: DataResponse<Any>, mapping: @escaping () -> Mapping, completion: @escaping RequestCompletion<Mapping>) {
        
        do {
            let value = try response.extractValue()
            let json = try JSONValue(object: value)
            
            if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                throw queryError
            }
            
            self.queue.addOperation { [weak self] in
                self?.map(json: json, mapping: mapping, completion: completion)
            }
        }
        catch let e {
            self.fail(error: e, mapping: mapping, completion: completion)
        }
    }
    
    private func map<M: Crust.Mapping, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>
        (json: JSONValue,
         mapping: @escaping () -> M,
         completion: @escaping RequestCompletion<M>)
        where M: ArrayMapping<SubType, SubAdaptor, SubMapping>, SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType, SubType: ThreadUnsafe {
            
            do {
                let map = mapping()
                let mapper = Mapper<M>()
                let result: [SubType] = try mapper.map(from: json, using: map)
                self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
            }
            catch let e {
                self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
            }
    }
    
    private func map<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe>(json: JSONValue, mapping: @escaping () -> Mapping, completion: @escaping RequestCompletion<Mapping>) where Mapping.MappedObject == MappedObject {
        do {
            let map = mapping()
            let mapper = Mapper<Mapping>()
            let result = try mapper.map(from: json, using: map)
            
            self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
        }
        catch let e {
            self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
        }
    }
    
    private func map<Mapping: Crust.Mapping>(json: JSONValue, mapping: @escaping () -> Mapping, completion: @escaping RequestCompletion<Mapping>) {
        do {
            let map = mapping()
            let mapper = Mapper<Mapping>()
            let result = try mapper.map(from: json, using: map)
            
            self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
        }
        catch let e {
            self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
        }
    }

    private func fail<Mapping: Crust.Mapping>(error: Error, mapping: () -> Mapping, completion: @escaping RequestCompletion<Mapping>) {
        self.callbackQueue.addOperation {
            completion(.failure(error))
        }
    }

    private func refetchAndComplete<Mapping: Crust.Mapping>
        (result: Mapping.MappedObject,
         json: JSONValue,
         mapping: @escaping () -> Mapping,
         completion: @escaping RequestCompletion<Mapping>) {
        
        self.callbackQueue.addOperation {
            completion(.success(result))
        }
    }
    
    private func refetchAndComplete<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe>
        (result: MappedObject,
         json: JSONValue,
         mapping: @escaping () -> Mapping,
         completion: @escaping RequestCompletion<Mapping>)
        where Mapping.MappedObject == MappedObject {
            
            let primaryKey = MappedObject.primaryKey()!
            let primaryKeys: [[String : CVarArg]] = {
                guard case let value as CVarArg = result.value(forKeyPath: primaryKey) else {
                    return []
                }
                return [[primaryKey : value]]
            }()
            
            self.callbackQueue.addOperation {
                let map = mapping()
                guard let finalResult = map.adaptor.fetchObjects(type: MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: primaryKeys, isMapping: false)?.first else {
                    self.fail(error: AutoGraphError.refetching, mapping: mapping, completion: completion)
                    return
                }
                completion(.success(finalResult as! MappedObject))
            }
    }
    
    private func refetchAndComplete<M: Crust.Mapping, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>
        (result: M.MappedObject,
         json: JSONValue,
         mapping: @escaping () -> M,
         completion: @escaping RequestCompletion<M>)
    where M: ArrayMapping<SubType, SubAdaptor, SubMapping>, SubMapping.AdaptorKind == SubAdaptor, SubMapping.MappedObject == SubType, SubType: ThreadUnsafe {
        
        let primaryKey = SubType.primaryKey()!
        let primaryKeys: [[String : CVarArg]] = result.flatMap {
            guard case let value as CVarArg = $0.value(forKeyPath: primaryKey) else {
                return nil
            }
            return [primaryKey : value]
        }
        
        func typeCoercion<T>(type: T.Type, obj: Any) -> T {
            return obj as! T
        }
        
        self.callbackQueue.addOperation {
            let map = mapping()
            guard let results = map.adaptor.fetchObjects(type: SubType.self as! SubAdaptor.BaseType.Type, primaryKeyValues: primaryKeys, isMapping: false) else {
                completion(.success([]))
                return
            }
            let mappedResults = results.map { $0 }
            let type = type(of: map).MappedObject.self
            // Note: as! M.MappedObject leads to "Ambiguous type name" bug for some weird reason.
            let success = Result.success(typeCoercion(type: type, obj: mappedResults))
            completion(success)
        }
    }
}
