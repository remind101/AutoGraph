/// Include this file and `RLMSupport.swift` in order to use `RealmMapping` and `RealmAdaptor` and map to `RLMObject` using `Crust`.
import AutoGraph
import Foundation
import Crust
import JSONValueRX
import Realm

public class RealmArrayAdaptor<RealmObject: RLMObject>: AbstractArrayAdaptor<RealmObject, RealmAdaptor> {
    public let realm: RLMRealm
    public let realmAdaptor: RealmAdaptor
    
    public init(realm: RLMRealm) {
        self.realm = realm
        self.realmAdaptor = RealmAdaptor(realm: realm)
        super.init(subAdaptor: self.realmAdaptor)
    }
    
    public convenience init() {
        self.init(realm: RLMRealm.default())
    }
}

public class RealmAdaptor: Adaptor {
    
    public typealias BaseType = RLMObject
    public typealias ResultsType = [BaseType]
    
    private var cache: Set<BaseType>
    public let realm: RLMRealm
    public var requiresPrimaryKeys = false
    
    public init(realm: RLMRealm) {
        self.realm = realm
        self.cache = []
    }
    
    public convenience init() throws {
        self.init(realm: RLMRealm.default())
    }
    
    public func mappingBegins() throws {
        self.realm.beginWriteTransaction()
    }
    
    public func mappingEnded() throws {
        try self.realm.commitWriteTransaction()
        self.cache.removeAll()
    }
    
    public func mappingErrored(_ error: Error) {
        if self.realm.inWriteTransaction {
            self.realm.cancelWriteTransaction()
        }
        self.cache.removeAll()
    }
    
    public func createObject(type: BaseType.Type) throws -> BaseType {
        let obj = type.init()
        self.cache.insert(obj)
        return obj
    }
    
    public func save(objects: [BaseType]) throws {
        let saveBlock = {
            for obj in objects {
                self.cache.remove(obj)
                if obj.objectSchema.primaryKeyProperty != nil {
                    self.realm.addOrUpdate(obj)
                }
                else if !self.requiresPrimaryKeys {
                    self.realm.add(obj)
                }
                else {
                    let userInfo = [ NSLocalizedFailureReasonErrorKey : "Adaptor requires primary keys but obj of type \(type(of: obj)) does not have one" ]
                    throw NSError(domain: "RealmAdaptorDomain", code: -1, userInfo: userInfo)
                }
            }
        }
        if self.realm.inWriteTransaction {
            try saveBlock()
        } else {
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
        } else {
            self.realm.beginWriteTransaction()
            deleteBlock()
            try self.realm.commitWriteTransaction()
        }
    }
    
    public func fetchObjects(type: BaseType.Type, primaryKeyValues: [[String : CVarArg]], isMapping: Bool) -> ResultsType? {
        
        // Really we should be using either a mapping associated with the primary key or the primary key's
        // Type's `fromJson(_:)` method. Unfortunately that method comes from JSONable which you cannot
        // dynamically typecast to and Swift's reflection system doesn't appear fully baked enough to safely
        // get the actual type of the property to call it's conversion method (Optional values aren't
        // properly reflected coming from sources on SO). In the meantime we'll have to convert here on a
        // case-by-case basis and possibly integrate better generics or primary key method mappings in the future.
        
        func sanitize(key: String, value: NSObject) -> NSObject {
            if type.isProperty(key, ofType: NSDate.self), case let value as String = value {
                return Date(isoString: value)! as NSDate
            }
            return type.sanitizeValue(value, fromProperty: key, realm: self.realm)
        }
        
        var totalPredicate = Array<NSPredicate>()
        
        for keyValues in primaryKeyValues {
            var objectPredicates = Array<NSPredicate>()
            for (key, var value) in keyValues {
                if case let obj as NSObject = value {
                    value = sanitize(key: key, value: obj)
                }
                let predicate = NSPredicate(format: "%K == %@", key, value)
                objectPredicates.append(predicate)
            }
            let objectPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: objectPredicates)
            totalPredicate.append(objectPredicate)
        }
        
        let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: totalPredicate)
        
        return fetchObjects(type: type, predicate: orPredicate, isMapping: isMapping)
    }
    
    public func fetchObjects(type: BaseType.Type, predicate: NSPredicate, isMapping: Bool) -> ResultsType? {
        
        var objects = self.cache.filter {
            type(of: $0) == type
            }.filter {
                predicate.evaluate(with: $0)
        }
        
        if objects.count > 0 {
            return Array(objects)
        }
        
        // Since we use this function to fetch existing objects to map to, but we can't remap the primary key,
        // we're going to build an unstored object and update when saving based on the primary key.
        guard !isMapping || type.primaryKey() == nil else {
            return nil
        }
        
        let results = type.objects(in: realm, with: predicate)
        for obj in results {
            objects.append(obj)
        }
        return objects
    }
}

public protocol RealmMapping: Mapping {
    init(adaptor: RealmAdaptor)
}

extension RLMArray: Appendable {
    public func findIndex(of object: RLMObject) -> UInt {
        guard case let index as UInt = self.index(ofObjectNonGeneric: object) else {
            return UInt.max
        }
        return index
    }
    
    public typealias Index = UInt
    
    public func append(_ newElement: RLMObject) {
        self.addObjectNonGeneric(newElement)
    }
    
    public func append(contentsOf newElements: [RLMObject]) {
        for obj in newElements {
            self.addObjectNonGeneric(obj)
        }
    }
    
    public func remove(at i: UInt) {
        self.removeObject(at: i)
    }
    
    public func removeAll(keepingCapacity keepCapacity: Bool) {
        self.removeAllObjects()
    }
}
