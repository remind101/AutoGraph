import Foundation
import Crust
import JSONValueRX
import Realm

public class RealmArrayAdaptor<T: RLMObject>: Adaptor {
    public typealias BaseType = [T]
    public typealias ResultsType = [BaseType]
    
    public let realm: RLMRealm
    public let realmAdaptor: RealmAdaptor
    
    public init(realm: RLMRealm) {
        self.realm = realm
        self.realmAdaptor = RealmAdaptor(realm: realm)
    }
    
    public convenience init() throws {
        self.init(realm: RLMRealm())
    }
    
    public func mappingBegins() throws {
        try self.realmAdaptor.mappingBegins()
    }
    
    public func mappingEnded() throws {
        try self.realmAdaptor.mappingEnded()
    }
    
    public func mappingErrored(_ error: Error) {
        self.realmAdaptor.mappingErrored(error)
    }
    
    public func fetchObjects(type: BaseType.Type, keyValues: [String : CVarArg]) -> ResultsType? {
        return nil
    }
    
    public func createObject(type: BaseType.Type) throws -> BaseType {
        return []
    }
    
    public func deleteObject(_ obj: BaseType) throws { }
    
    public func save(objects: [BaseType]) throws { }
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
        self.init(realm: RLMRealm())
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
    
    public func fetchObjects(type: BaseType.Type, keyValues: [String : CVarArg]) -> ResultsType? {
        
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
        
        var predicates = Array<NSPredicate>()
        for (key, var value) in keyValues {
            if case let obj as NSObject = value {
                value = sanitize(key: key, value: obj)
            }
            let predicate = NSPredicate(format: "%K == %@", key, value)
            predicates.append(predicate)
        }
        
        let andPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        return fetchObjects(type: type, predicate: andPredicate)
    }
    
    public func fetchObjects(type: BaseType.Type, predicate: NSPredicate) -> ResultsType? {
        
        var objects = self.cache.filter {
            type(of: $0) == type
            }.filter {
                predicate.evaluate(with: $0)
        }
        if objects.count > 0 {
            return Array(objects)
        }
        
        if type.primaryKey() != nil {
            // We're going to build an unstored object and update when saving based on the primary key.
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
    associatedtype AdaptorKind = RealmAdaptor
    init(adaptor: AdaptorKind)
}

public protocol RealmArrayMapping: Mapping {
    associatedtype SubType: RLMObject
    associatedtype AdaptorKind = RealmArrayAdaptor<SubType>
    init(adaptor: AdaptorKind)
}

extension RealmArrayMapping {
    public var primaryKeys: [String : Keypath]? { return nil }
}

extension RLMArray: Appendable {
    public func append(_ newElement: RLMObject) {
        self.addObjectNonGeneric(newElement)
    }
    
    public func append(contentsOf newElements: [RLMObject]) {
        for obj in newElements {
            self.addObjectNonGeneric(obj)
        }
    }
}

@discardableResult
public func <- <T, U: Mapping, C: MappingContext>(field: inout RLMArray<T>, map:(key: Spec<U>, context: C)) -> C
    where U.MappedObject == T {
        
        // Realm specifies that List "must be declared with 'let'". Seems to actually work either way in practice, but for safety
        // we're going to include a List mapper that accepts fields with a 'let' declaration and forward to our
        // `RangeReplaceableCollectionType` mapper.
        
        var variableList = field.allObjects() as! [T]
        let context = mapCollectionField(&variableList, map: map)
        field.append(contentsOf: variableList)
        return context
}
