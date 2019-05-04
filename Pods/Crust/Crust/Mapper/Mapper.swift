import Foundation
import JSONValueRX

public enum MappingDirection {
    case fromJSON
    case toJSON
}

enum MapperError: LocalizedError {
    case primaryKeyMissing(keyPath: String, mappingType: Any.Type)          // TODO-Swift-5: opaque Mapping
    case mappedObjectCannotWriteToAdapter(objectType: Any.Type, adapterBaseType: Any.Type)
    case mappingWillBeginErrored(adapter: Any, underlyingError: Error)      // TODO-Swift-5: opaque PersistanceAdapter
    case mappingDidEndErrored(adapter: Any, underlyingError: Error)         // TODO-Swift-5: opaque PersistanceAdapter
    
    var errorDescription: String? {
        switch self {
        case .primaryKeyMissing(let keyPath, let mappingType):
            return "Primary key of \(String(describing: keyPath)) does not exist in JSON but is expected from mapping \(mappingType)"
        case .mappedObjectCannotWriteToAdapter(let objectType, let adapterBaseType):
            return "Mapping.MappedObject of \(objectType) cannot write to PersistanceAdapter with BaseType \(adapterBaseType). Type of object \(objectType) is not a subtype of \(adapterBaseType)"
        case .mappingWillBeginErrored(let adapter, let underlyingError):
            return "Errored during mappingWillBegin for PersistanceAdapter \(adapter). Underlying error: \(underlyingError)"
        case .mappingDidEndErrored(let adapter, let underlyingError):
            return "Errored during mappingDidEnd for PersistanceAdapter \(adapter). Underlying error: \(underlyingError)"
        }
    }
}

open class MappingPayload<K: MappingKey> {
    open internal(set) var json: JSONValue
    open internal(set) var keys: AnyKeyCollection<K>
    open internal(set) var object: Any
    open internal(set) var error: Error?
    open internal(set) var parent: MappingPayload<AnyMappingKey>? = nil
    open internal(set) var adapterType: String
    open fileprivate(set) var dir: MappingDirection
    
    convenience init(withObject object: Any, json: JSONValue, keys: [K], adapterType: String, direction: MappingDirection) {
        self.init(withObject: object, json: json, keys: Set(keys), adapterType: adapterType, direction: direction)
    }
    
    init<P: KeyCollection>(withObject object: Any, json: JSONValue, keys: P, adapterType: String, direction: MappingDirection) where P.MappingKeyType == K {
        self.object = object
        self.json = json
        self.keys = AnyKeyCollection(keys)
        self.adapterType = adapterType
        self.dir = direction
    }
    
    internal func typeErased() -> MappingPayload<AnyMappingKey> {
        let keys = AnyMappingKeyKeyCollection(self.keys)
        let parent = MappingPayload<AnyMappingKey>(withObject: self.object, json: self.json, keys: keys, adapterType: self.adapterType, direction: self.dir)
        parent.error = self.error
        parent.parent = self.parent
        return parent
    }
}

/// Method caller used to perform mappings.
public struct Mapper {
    
    public init() { }
    
    // MARK: - Map Collections.
    
    // Equatable Collections.
    public func map<M, C: RangeReplaceableCollection, K>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: Set<M.MappingKeyType>) throws -> C
        where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable {
            
            return try self.map(from: json, using: binding, keyedBy: Set(keys), parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KP>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: Set<M.MappingKeyType>, parentPayload: MappingPayload<KP>?) throws -> C
        where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable {
            
            return try self.map(from: json, using: binding, keyedBy: Set(keys), parentPayload: parentPayload)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC) throws -> C
        where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable, KC.MappingKeyType == M.MappingKeyType {
            return try self.map(from: json, using: binding, keyedBy: keys, parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KP, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC, parentPayload: MappingPayload<KP>?) throws -> C
    where M.MappedObject == C.Iterator.Element, M.MappedObject: Equatable, KC.MappingKeyType == M.MappingKeyType {
        
        var collection = C()
        let codingKey = NestedMappingKey(rootKey: binding.key, nestedKeys: keys)
        let payload = MappingPayload(withObject: collection, json: json, keys: codingKey, adapterType: binding.mapping.adapter.dataBaseTag, direction: MappingDirection.fromJSON)
        payload.parent = parentPayload?.typeErased()
        
        try binding.mapping.start(payload: payload)
        collection <- (binding, payload)
        try binding.mapping.completeMapping(collection: collection, payload: payload)
        
        return collection
    }
    
    // Non-equatable Collections.
    public func map<M, C: RangeReplaceableCollection, K>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: Set<M.MappingKeyType>) throws -> C where M.MappedObject == C.Iterator.Element {
        
        return try self.map(from: json, using: binding, keyedBy: Set(keys), parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KP>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: Set<M.MappingKeyType>, parentPayload: MappingPayload<KP>?) throws -> C where M.MappedObject == C.Iterator.Element {
        
        return try self.map(from: json, using: binding, keyedBy: Set(keys), parentPayload: parentPayload)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC) throws -> C
        where M.MappedObject == C.Iterator.Element, KC.MappingKeyType == M.MappingKeyType {
            return try self.map(from: json, using: binding, keyedBy: keys, parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, C: RangeReplaceableCollection, K, KP, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC, parentPayload: MappingPayload<KP>?) throws -> C
        where M.MappedObject == C.Iterator.Element, KC.MappingKeyType == M.MappingKeyType {
            
            var collection = C()
            let codingKey = NestedMappingKey(rootKey: binding.key, nestedKeys: keys)
            let payload = MappingPayload(withObject: collection, json: json, keys: codingKey, adapterType: binding.mapping.adapter.dataBaseTag, direction: MappingDirection.fromJSON)
            payload.parent = parentPayload?.typeErased()
            
            try binding.mapping.start(payload: payload)
            collection <- (binding, payload)
            try binding.mapping.completeMapping(collection: collection, payload: payload)
            
            return collection
    }
    
    // MARK: - Map using Binding.
    
    public func map<M, K>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: Set<M.MappingKeyType>) throws -> M.MappedObject {
        return try self.map(from: json, using: binding, keyedBy: Set(keys), parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, K, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        return try self.map(from: json, using: binding, keyedBy: keys, parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M, K, KP, KC: KeyCollection>(from json: JSONValue, using binding: Binding<K, M>, keyedBy keys: KC, parentPayload: MappingPayload<KP>?) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        
        let baseJson = try baseJSON(from: json, via: binding.key, ifIn: Set([binding.key])) ?? json
        let parent = parentPayload?.typeErased()
        
        var object = try binding.mapping.fetchOrCreateObject(from: baseJson, in: parent)
        let codingKey = NestedMappingKey(rootKey: binding.key, nestedKeys: keys)
        let payload = MappingPayload(withObject: object, json: json, keys: codingKey, adapterType: binding.mapping.adapter.dataBaseTag, direction: MappingDirection.fromJSON)
        payload.parent = parent
        
        let mapping = binding.mapping
        try mapping.start(payload: payload)
        object <- (binding, payload)
        try mapping.complete(object: &object, payload: payload)
        
        return object
    }
    
    // MARK: - Map using Mapping.
    
    public func map<M: Mapping>(from json: JSONValue, using mapping: M, keyedBy keys: Set<M.MappingKeyType>) throws -> M.MappedObject {
        return try self.map(from: json, using: mapping, keyedBy: Set(keys), parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M: Mapping, KC: KeyCollection>(from json: JSONValue, using mapping: M, keyedBy keys: KC) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        return try self.map(from: json, using: mapping, keyedBy: keys, parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M: Mapping, KP, KC: KeyCollection>(from json: JSONValue, using mapping: M, keyedBy keys: KC, parentPayload: MappingPayload<KP>?) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        let object = try mapping.fetchOrCreateObject(from: json, in: parentPayload?.typeErased())
        return try self.map(from: json, to: object, using: mapping, keyedBy: keys, parentPayload: parentPayload)
    }
    
    public func map<M: Mapping, KC: KeyCollection>(from json: JSONValue, to object: M.MappedObject, using mapping: M, keyedBy keys: KC) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        return try map(from: json, to: object, using: mapping, keyedBy: keys, parentPayload: Optional<MappingPayload<RootKey>>.none)
    }
    
    public func map<M: Mapping, KP, KC: KeyCollection>(from json: JSONValue, to object: M.MappedObject, using mapping: M, keyedBy keys: KC, parentPayload: MappingPayload<KP>?) throws -> M.MappedObject where KC.MappingKeyType == M.MappingKeyType {
        var object = object
        let payload = MappingPayload(withObject: object, json: json, keys: keys, adapterType: mapping.adapter.dataBaseTag, direction: MappingDirection.fromJSON)
        payload.parent = parentPayload?.typeErased()
        try self.perform(mapping, on: &object, with: payload)
        return object
    }
    
    public func mapFromObjectToJSON<M: Mapping, KC: KeyCollection>(_ object: M.MappedObject, mapping: M, keyedBy keys: KC) throws -> JSONValue where KC.MappingKeyType == M.MappingKeyType {
        var object = object
        let payload = MappingPayload(withObject: object, json: JSONValue.object([:]), keys: keys, adapterType: mapping.adapter.dataBaseTag, direction: MappingDirection.toJSON)
        try self.perform(mapping, on: &object, with: payload)
        return payload.json
    }
    
    internal func perform<M: Mapping>(_ mapping: M, on object: inout M.MappedObject, with payload: MappingPayload<M.MappingKeyType>) throws {
        try mapping.start(payload: payload)
        mapping.execute(object: &object, payload: payload)
        try mapping.complete(object: &object, payload: payload)
    }
}

public extension Mapping {
    func fetchOrCreateObject(from json: JSONValue, in parentPayload: MappingPayload<AnyMappingKey>?) throws -> MappedObject {
        guard let primaryKeyValues = try self.primaryKeyValuePairs(from: json, in: parentPayload) else {
            return try self.generateNewInstance()
        }
        
        let (object, newInstance) = try { () -> (MappedObject, Bool) in
            guard let object = try self.fetchExistingInstance(json: json, primaryKeyValues: primaryKeyValues, parentPayload: parentPayload) else {
                return try (self.generateNewInstance(), true)
            }
            return (object, false)
        }()
        
        if case let nsObject as NSObject = object, newInstance {
            primaryKeyValues.forEach { (key, value) in
                nsObject.setValue(value, forKey: key)
            }
        }
        
        return object
    }
    
    func primaryKeyValuePairs(from json: JSONValue, in parentPayload: MappingPayload<AnyMappingKey>?) throws -> [String: CVarArg]? {
        guard let primaryKeys = self.primaryKeys else {
            return nil
        }
        
        try self.checkForAdapterBaseTypeConformance()
        
        var keyValues = [String : CVarArg]()
        try primaryKeys.forEach { (primaryKey, keyPath, transform) in
            let key = keyPath?.keyPath
            let baseJson = key != nil ? json[key!] : json
            if let val = baseJson {
                let transformedVal: CVarArg = try transform?(val, parentPayload) ?? val.valuesAsNSObjects()
                let sanitizedVal = self.adapter.sanitize(primaryKeyProperty: primaryKey,
                                                         forValue: transformedVal,
                                                         ofType: MappedObject.self as! AdapterKind.BaseType.Type)
                
                keyValues[primaryKey] = sanitizedVal ?? transformedVal
            }
            else {
                throw MapperError.primaryKeyMissing(keyPath: String(describing: keyPath), mappingType: Self.self)
            }
        }
        return keyValues
    }
    
    func fetchExistingInstance(json: JSONValue, primaryKeyValues: [String : CVarArg]?, parentPayload: MappingPayload<AnyMappingKey>?) throws -> MappedObject? {
        
        try self.checkForAdapterBaseTypeConformance()
        
        guard let keyValues = try (primaryKeyValues ?? self.primaryKeyValuePairs(from: json, in: parentPayload)) else {
            return nil
        }
        
        guard let obj = self.adapter.fetchObjects(baseType: MappedObject.self as! AdapterKind.BaseType.Type, primaryKeyValues: [keyValues], isMapping: true)?.first else {
            return nil
        }
        
        return unsafeBitCast(obj, to: MappedObject.self)
    }
    
    func generateNewInstance() throws -> MappedObject {
        
        try self.checkForAdapterBaseTypeConformance()
        
        let obj = try self.adapter.createObject(baseType: MappedObject.self as! AdapterKind.BaseType.Type)
        return unsafeBitCast(obj, to: MappedObject.self)
    }
    
    func delete(obj: MappedObject) throws {
        try self.checkForAdapterBaseTypeConformance()
        
        try self.adapter.deleteObject(obj as! AdapterKind.BaseType)
    }
    
    internal func checkForAdapterBaseTypeConformance() throws {
        // NOTE: This sux but `MappedObject: AdapterKind.BaseType` as a type constraint throws a compiler error as of 7.1 Xcode
        // and `MappedObject == AdapterKind.BaseType` doesn't work with sub-types (i.e. expects MappedObject to be that exact type)
        
        guard MappedObject.self is AdapterKind.BaseType.Type else {
            throw MapperError.mappedObjectCannotWriteToAdapter(objectType: MappedObject.self, adapterBaseType: AdapterKind.BaseType.self)
        }
    }
    
    internal func start<K>(payload: MappingPayload<K>) throws {
        try self.checkForAdapterBaseTypeConformance()
        if payload.parent == nil || !self.adapter.isInTransaction {
            do {
                try self.adapter.mappingWillBegin()
            }
            catch let e {
                throw MapperError.mappingWillBeginErrored(adapter: self.adapter, underlyingError: e)
            }
        }
    }
    
    internal func endMapping<K>(payload: MappingPayload<K>) throws {
        let shouldCallEndMapping = { () -> Bool in 
            guard payload.parent != nil else {
                return true
            }
            
            // Walk parent payloads, if using the same adapter type assume that we'll call end mapping later.
            let adapterType = payload.adapterType
            var payload: MappingPayload<AnyMappingKey> = payload.typeErased()
            while let parent = payload.parent {
                if parent.adapterType == adapterType {
                    return false
                }
                payload = parent
            }
            
            return true
        }()
        
        if shouldCallEndMapping {
            do {
                try self.adapter.mappingDidEnd()
            }
            catch let err {
                throw MapperError.mappingDidEndErrored(adapter: self.adapter, underlyingError: err)
            }
        }
    }
    
    func execute(object: inout MappedObject, payload: MappingPayload<MappingKeyType>) {
        do {
            try self.mapping(toMap: &object, payload: payload)
        }
        catch let e {
            payload.error = e
        }
    }
    
    internal func complete<K>(object: inout MappedObject, payload: MappingPayload<K>) throws {
        try self.completeMapping(objects: [object], payload: payload)
        payload.object = object
    }
    
    internal func completeMapping<C: Sequence, K>(collection: C, payload: MappingPayload<K>) throws where C.Iterator.Element == MappedObject {
        try self.completeMapping(objects: collection, payload: payload)
        payload.object = collection
    }
    
    internal func completeMapping<C: Sequence, K>(objects: C, payload: MappingPayload<K>) throws where C.Iterator.Element == MappedObject {
        if payload.error == nil {
            do {
                try self.checkForAdapterBaseTypeConformance()
                let objects = objects.map { unsafeBitCast($0, to: AdapterKind.BaseType.self) }
                try self.adapter.save(objects: objects)
            }
            catch let error {
                payload.error = error
            }
        }
        
        if let error = payload.error {
            if payload.parent == nil {
                self.adapter.mappingErrored(error)
            }
            throw error
        }
        
        try self.endMapping(payload: payload)
    }
}
