/// Include this file and `RLMSupport.swift` in order to use `RealmMapping` and `RealmAdapter` and map to `RLMObject` using `Crust`.

import AutoGraphQL
import Crust
import Foundation
import JSONValueRX
import Realm
import RealmSwift

public let RealmAdapterDomain = "RealmAdapterDomain"

public class RealmAdapter: PersistanceAdapter {
    public typealias BaseType = RLMObject
    public typealias ResultsType = [BaseType]
    
    private var cache: Set<BaseType>
    public let realm: RLMRealm
    public let dataBaseTag: String = DefaultDatabaseTag.realm.rawValue
    public var requiresPrimaryKeys = false
    
    public required init(realm: RLMRealm) {
        self.realm = realm
        self.cache = []
    }
    
    public convenience init() throws {
        self.init(realm: RLMRealm.default())
    }
    
    public var isInTransaction: Bool {
        return self.realm.inWriteTransaction
    }
    
    public func mappingWillBegin() throws {
        self.realm.beginWriteTransaction()
    }
    
    public func mappingDidEnd() throws {
        try self.realm.commitWriteTransaction()
        self.cache.removeAll()
    }
    
    public func mappingErrored(_ error: Error) {
        if self.realm.inWriteTransaction {
            self.realm.cancelWriteTransaction()
        }
        self.cache.removeAll()
    }
    
    public func createObject(baseType type: RLMObject.Type) throws -> RLMObject {
        let obj = type.init()
        self.cache.insert(obj)
        return obj
    }
    
    public func save(objects: [BaseType]) throws {
        let saveBlock = {
            for obj in objects {
                self.cache.remove(obj)
                obj.sanitizeValues(in: self.realm)
                if obj.objectSchema.primaryKeyProperty != nil {
                    self.realm.addOrUpdate(obj)
                }
                else if !self.requiresPrimaryKeys {
                    self.realm.add(obj)
                }
                else {
                    let userInfo = [ NSLocalizedFailureReasonErrorKey : "Adapter requires primary keys but obj of type \(type(of: obj)) does not have one" ]
                    throw NSError(domain: RealmAdapterDomain, code: -1, userInfo: userInfo)
                }
            }
        }
        if self.realm.inWriteTransaction {
            try saveBlock()
        }
        else {
            self.realm.beginWriteTransaction()
            try saveBlock()
            try self.realm.commitWriteTransaction()
        }
    }
    
    public func deleteObject(_ obj: BaseType) throws {
        let deleteBlock = {
            self.cache.remove(obj)
            self.realm.delete(obj)
        }
        if self.realm.inWriteTransaction {
            deleteBlock()
        }
        else {
            self.realm.beginWriteTransaction()
            deleteBlock()
            try self.realm.commitWriteTransaction()
        }
    }
    
    public func sanitize(primaryKeyProperty property: String, forValue value: CVarArg, ofType type: RLMObject.Type) -> CVarArg? {
        
        // Since Date is converted as such so often we won't require implementors to write their own transform.
        if type.isProperty(property, ofType: NSDate.self), case let value as String = value {
            return Date(isoString: value)! as NSDate
        }
        return type.sanitizeValue(value, fromProperty: property, realm: self.realm)
    }
    
    // TODO: This should throw and we should check that the primary key's type and value's sanitized type match.
    // Otherwise we get an exception from Realm here.
    public func fetchObjects(baseType: RLMObject.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType? {
        
        var totalPredicate = [NSPredicate]()
        
        for keyValues in primaryKeyValues {
            var objectPredicates = [NSPredicate]()
            for (key, var value) in keyValues {
                value = self.sanitize(primaryKeyProperty: key, forValue: value, ofType: baseType) ?? value
                let predicate = NSPredicate(format: "%K == %@", key, value)
                objectPredicates.append(predicate)
            }
            let objectPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: objectPredicates)
            totalPredicate.append(objectPredicate)
        }
        
        let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: totalPredicate)
        
        return fetchObjects(baseType: baseType, predicate: orPredicate, isMapping: isMapping)
    }
    
    public func fetchObjects(baseType: BaseType.Type, predicate: NSPredicate, isMapping: Bool) -> ResultsType? {
        
        var objects = self.cache.filter {
            type(of: $0) == baseType
        }
        .filter {
                predicate.evaluate(with: $0)
        }
        
        if objects.count > 0 {
            return Array(objects)
        }
        
        let results = baseType.objects(in: realm, with: predicate)
        for obj in results {
            objects.insert(obj)
        }
        return Array(objects)
    }
}

public protocol RealmMapping: Mapping where MappedObject: RLMObject, AdapterKind: RealmAdapter {
    init(adapter: AdapterKind)
}

public class RealmThreadAdapter: ThreadAdapter {
    public typealias BaseType = RLMObject
    
    public init() { }
    
    public func threadSafeRepresentations(`for` objects: [RLMObject], ofType type: Any.Type) throws -> [RLMThreadSafeReference<RLMThreadConfined>] {
        return objects.map { RLMThreadSafeReference(threadConfined: $0) }
    }
    
    public func retrieveObjects(`for` representations: [RLMThreadSafeReference<RLMThreadConfined>]) throws -> [RLMObject] {
        let realm = RLMRealm.default()
        return representations.flatMap { realm.__resolve($0) as? RLMObject }
    }
}

extension RLMArray {
    @objc public func findIndex(of object: RLMObject) -> UInt {
        guard case let index as UInt = self.index(ofObjectNonGeneric: object) else {
            return UInt.max
        }
        return index
    }
    
    public typealias Index = UInt
    
    @objc public func append(_ newElement: RLMObject) {
        self.addObjectNonGeneric(newElement)
    }
    
    @objc public func append(contentsOf newElements: [RLMObject]) {
        for obj in newElements {
            self.addObjectNonGeneric(obj)
        }
    }
    
    @objc public func remove(at i: UInt) {
        self.removeObject(at: i)
    }
    
    @objc public func removeAll(keepingCapacity keepCapacity: Bool) {
        self.removeAllObjects()
    }
}

public class RealmSwiftObjectAdapterBridge<T>: PersistanceAdapter {
    public typealias BaseType = T
    public typealias ResultsType = [BaseType]
    
    public let realmObjCAdapter: RealmAdapter
    public let rlmObjectType: RLMObject.Type
    public let dataBaseTag: String = DefaultDatabaseTag.realm.rawValue
    
    public init(realmObjCAdapter: RealmAdapter, rlmObjectType: RLMObject.Type) {
        self.realmObjCAdapter = realmObjCAdapter
        self.rlmObjectType = rlmObjectType
    }
    
    public var isInTransaction: Bool {
        return self.realmObjCAdapter.isInTransaction
    }
    
    public func mappingWillBegin() throws {
        try self.realmObjCAdapter.mappingWillBegin()
    }
    
    public func mappingDidEnd() throws {
        try self.realmObjCAdapter.mappingDidEnd()
    }
    
    public func mappingErrored(_ error: Error) {
        self.realmObjCAdapter.mappingErrored(error)
    }
    
    public func createObject(baseType type: BaseType.Type) throws -> BaseType {
        let obj = try self.realmObjCAdapter.createObject(baseType: self.rlmObjectType)
        return unsafeBitCast(obj, to: BaseType.self)
    }
    
    public func save(objects: [BaseType]) throws {
        let rlmObjs = objects.map { unsafeDowncast($0 as AnyObject, to: type(of: self.realmObjCAdapter).BaseType.self) }
        try self.realmObjCAdapter.save(objects: rlmObjs)
    }
    
    public func deleteObject(_ obj: BaseType) throws {
        let rlmObj = unsafeDowncast(obj as AnyObject, to: type(of: self.realmObjCAdapter).BaseType.self)
        try self.realmObjCAdapter.deleteObject(rlmObj)
    }
    
    public func sanitize(primaryKeyProperty property: String, forValue value: CVarArg, ofType type: BaseType.Type) -> CVarArg? {
        return self.realmObjCAdapter.sanitize(primaryKeyProperty: property, forValue: value, ofType: type as! RLMObject.Type)
    }
    
    public func fetchObjects(baseType type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType? {
        guard let rlmObjects = self.realmObjCAdapter.fetchObjects(baseType: self.rlmObjectType,
                                                                  primaryKeyValues: primaryKeyValues,
                                                                  isMapping: isMapping)
            else {
                return nil
        }
        
        return rlmObjects.map { unsafeBitCast($0, to: BaseType.self) }
    }
}

/// Wrapper used to map `RLMObjects`. Relies on `RLMArrayBridge` since `RLMArray` does not support `RangeReplaceableCollection`.
public class RLMArrayMappingBridge<T: RLMObject, K: MappingKey>: Mapping {
    public typealias MappedObject = T
    
    public let adapter: RealmSwiftObjectAdapterBridge<MappedObject>
    public let primaryKeys: [Mapping.PrimaryKeyDescriptor]?
    public let rlmObjectMapping: (inout MappedObject, MappingPayload<K>) throws -> Void
    
    public required init<OGMapping: RealmMapping>(rlmObjectMapping: OGMapping) where OGMapping.MappedObject == T, OGMapping.MappingKeyType == K {
        
        self.adapter = RealmSwiftObjectAdapterBridge(realmObjCAdapter: rlmObjectMapping.adapter as RealmAdapter,
                                                     rlmObjectType: OGMapping.MappedObject.self)
        self.primaryKeys = rlmObjectMapping.primaryKeys
        
        self.rlmObjectMapping = { (toMap: inout MappedObject, payload: MappingPayload<K>) throws -> Void in
            var ogObject = unsafeDowncast(toMap, to: OGMapping.MappedObject.self)
            try rlmObjectMapping.mapping(toMap: &ogObject, payload: payload)
        }
    }
    
    public final func mapping(toMap: inout MappedObject, payload: MappingPayload<K>) throws {
        try self.rlmObjectMapping(&toMap, payload)
    }
}

public extension Binding where M: RealmMapping {
    func generateRLMArrayMappingBridge() -> Binding<K, RLMArrayMappingBridge<M.MappedObject, M.MappingKeyType>> {
        switch self {
        case .mapping(let keyPath, let mapping):
            let bridge = RLMArrayMappingBridge(rlmObjectMapping: mapping)
            return .mapping(keyPath, bridge)
            
        case .collectionMapping(let keyPath, let mapping, let updatePolicy):
            let bridge = RLMArrayMappingBridge<M.MappedObject, M.MappingKeyType>(rlmObjectMapping: mapping)
            return .collectionMapping(keyPath, bridge, updatePolicy)
        }
    }
}

@discardableResult
public func <- <U: RealmMapping, K, C: MappingPayload<K>>(field: RLMArray<U.MappedObject>, binding:(key: Binding<K, U>, payload: C)) -> C {
    return map(toRLMArray: field, using: binding)
}

@discardableResult
public func map<U: RealmMapping, K, C: MappingPayload<K>>(toRLMArray field: RLMArray<U.MappedObject>, using binding:(key: Binding<K, U>, payload: C)) -> C {
    
    var variableList = RLMArrayBridge(rlmArray: field)
    let bridge = binding.key.generateRLMArrayMappingBridge()
    return map(toCollection: &variableList, using: (bridge, binding.payload))
}

// NSNumber<RLMInt>

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMInt), keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMInt)?, keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMInt), via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
    
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMInt)?, via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber? = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}

// NSNumber<RLMBool>

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMBool), keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMBool)?, keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMBool), via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
    
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMBool)?, via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber? = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}

// NSNumber<RLMDouble>

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMDouble), keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMDouble)?, keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMDouble), via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMDouble)?, via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber? = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}

// NSNumber<RLMFloat>

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMFloat), keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

@discardableResult
public func <- <K, MC: MappingPayload<K>>(field: inout (NSNumber & RLMFloat)?, keyPath:(key: K, payload: MC)) -> MC {
    return map(to: &field, via: keyPath)
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMFloat), via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}

public func map<K, MC: MappingPayload<K>>(to field: inout (NSNumber & RLMFloat)?, via keyPath:(key: K, payload: MC)) -> MC {
    var realmNumber: NSNumber? = field
    realmNumber <- keyPath
    field = realmNumber
    return keyPath.payload
}
