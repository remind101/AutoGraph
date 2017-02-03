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
    /*
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
    */
    
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
    
    // MARK: - Handle single objects.
    
    func handle<Mapping: Crust.Mapping>(
        response: DataResponse<Any>,
        mapping: @escaping () -> Mapping,
        completion: @escaping RequestCompletion<Mapping.MappedObject>)
    where Mapping.MappedObject: ThreadUnsafe {
        
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
    
    func handle<Mapping: Crust.Mapping>(
        response: DataResponse<Any>,
        mapping: @escaping () -> Mapping,
        completion: @escaping RequestCompletion<Mapping.MappedObject>) {
        
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
    
    // MARK: - Handle RangeReplaceableCollection.
    // TODO:
    
    
    
    /*
    private func map<M: Crust.Mapping, SubType: Equatable, SubAdaptor: Adaptor, SubMapping: ArraySubMapping>(
        json: JSONValue,
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
    */
    
    /// test
    
    private func map<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(
        json: JSONValue,
        resultSpec: ResultSpec<M, CM, C>) {
            
            do {
                switch resultSpec {
                case .object(let mapping, let completion):
                    let mapper = Mapper<M>()
                    let result = try mapper.map(from: json, using: mapping())
                    
                    self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
                    
                case .collection(mapping: let mapping, completion: let completion):
                    let mapper = Mapper<CM>()
                    let spec = Spec.mapping("", mapping())
                    let result: C = try mapper.map(from: json, using: spec)
                    
                    self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
                }
            }
            catch let e {
                switch resultSpec {
                case .object(let mapping, let completion):
                    self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
                case .collection(mapping: let mapping, completion: let completion):
                    self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
                }
            }
    }
    
    // MARK: - Map single objects.
    
    private func map<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe>(
        json: JSONValue,
        mapping: @escaping () -> Mapping,
        completion: @escaping RequestCompletion<Mapping.MappedObject>)
        where Mapping.MappedObject == MappedObject {
            
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
    
    private func map<Mapping: Crust.Mapping>(
        json: JSONValue,
        mapping: @escaping () -> Mapping,
        completion: @escaping RequestCompletion<Mapping.MappedObject>) {
        
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
    
    // MARK: - Map RangeReplaceableCollection.
    
    private func map<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe, Result: RangeReplaceableCollection>(
        json: JSONValue,
        mapping: @escaping () -> Mapping,
        completion: @escaping RequestCompletion<Result>)
        where Mapping.MappedObject == MappedObject, MappedObject: Equatable,
        Result.Iterator.Element == Mapping.MappedObject, Mapping.SequenceKind == Result {
            
            do {
                let map = mapping()
                let mapper = Mapper<Mapping>()
                let result: Result = try mapper.map(from: json, using: .mapping("", map))
                
                self.refetchAndComplete(result: result, json: json, mapping: mapping, completion: completion)
            }
            catch let e {
                self.fail(error: AutoGraphError.mapping(error: e), mapping: mapping, completion: completion)
            }
    }
    
    // MARK: - Post mapping.
    
    private func fail<Mapping: Crust.Mapping, R>(error: Error, mapping: () -> Mapping, completion: @escaping RequestCompletion<R>) {
        self.callbackQueue.addOperation {
            completion(.failure(error))
        }
    }
    
    private func fail<M: Mapping, CM: Mapping, C: RangeReplaceableCollection>(error: Error, resultSpec: ResultSpec<M, CM, C>) {
        switch resultSpec {
        case .object(let mapping, let completion):
            self.fail(error: AutoGraphError.mapping(error: error), mapping: mapping, completion: completion)
        case .collection(mapping: let mapping, completion: let completion):
            self.fail(error: AutoGraphError.mapping(error: error), mapping: mapping, completion: completion)
        }
    }

    private func refetchAndComplete<Mapping: Crust.Mapping, Result>
        (result: Result,
         json: JSONValue,
         mapping: @escaping () -> Mapping,
         completion: @escaping RequestCompletion<Result>) {
        
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
            let map = mapping()
            guard let finalResult = map.adaptor.fetchObjects(type: Mapping.MappedObject.self as! Mapping.AdaptorKind.BaseType.Type, primaryKeyValues: primaryKeys, isMapping: false)?.first else {
                self.fail(error: AutoGraphError.refetching, mapping: mapping, completion: completion)
                return
            }
            completion(.success(finalResult as! Result))
        }
    }
    
    private func refetchAndComplete<Mapping: Crust.Mapping, MappedObject: ThreadUnsafe>
        (result: MappedObject,
         json: JSONValue,
         mapping: @escaping () -> Mapping,
         completion: @escaping RequestCompletion<MappedObject>)
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
    
    /*
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
    */
}
