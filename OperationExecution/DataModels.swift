import Foundation

enum RecordConstructionError: LocalizedError {
    case jsonObjectFailedToConvertToRecord(path: Path, objectType: Any.Type)
}

/// A cache key for a record.
public typealias CacheKey = String

// TODO: this becomes a protocol and Field, Argument, Directive inherit from it.
/// A path traversed through JSON.
public typealias Path = [PathComponent]

/// The response key of a field (alias or name).
public typealias FieldResponseKey = String

/// A dictionary of cache keys to records.
public typealias RecordSet = [CacheKey: CacheRecord]

/// A set of CacheKeys which changed with an insertion.
public typealias CacheKeyChangeSet = Set<CacheKey>

/// A component in the path of traversing a query.
public protocol PathComponent {
    func sortedPathComponentString(variableValues: [AnyHashable : Any]) throws -> String
}

extension Int: PathComponent {
    public func sortedPathComponentString(variableValues: [AnyHashable : Any]) -> String {
        return String(self)
    }
}

extension Operation.OperationType: PathComponent {
    public func sortedPathComponentString(variableValues: [AnyHashable : Any]) -> String {
        return self.root
    }
}

extension Field: PathComponent {
    public func sortedPathComponentString(variableValues: [AnyHashable : Any]) throws -> String {
        let argumentValues = try ExecutorHelpers.coerceArgumentValues(objectType: "TODO", field: self, variableValues: variableValues)
        guard argumentValues.count > 0 else {
            return self.name
        }
        return "\(self.name)(\(argumentValues.sortedPathComponentString))"
    }
}

extension Dictionary where Key == AnyHashable {
    public var sortedPathComponentString: String {
        return self.sorted { String(describing: $0.key) < String(describing: $1.key) }.map {
            if case let object as Dictionary = $0.value {
                return "[\($0.key):\(object.sortedPathComponentString)]"
            } else {
                return "\($0.key):\($0.value)"
            }
        }.joined(separator: ",")
    }
}

extension Array where Element == PathComponent {
    func cacheKey(payload: CacheRecord.Payload, field: Field, variableValues: [AnyHashable : Any], cacheKeyFunc: CacheKeyForObject?) throws -> String {
        if let cacheKeyFunc = cacheKeyFunc {
            return cacheKeyFunc(payload, field, self, variableValues)
        }
        return try self.map { try $0.sortedPathComponentString(variableValues: variableValues) }.joined(separator: ".")
    }
}

/// A cache record.
public struct CacheRecord {
    indirect public enum PayloadValue: Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null
        case array([PayloadValue])
        case reference(RecordReference)
    }
    
    public typealias Payload = [FieldResponseKey: PayloadValue]
    public private(set) var payload: Payload
    public subscript(key: CacheKey) -> PayloadValue? {
        get {
            return payload[key]
        }
        set {
            payload[key] = newValue
        }
    }
    
    public let cacheKey: CacheKey   // Usually equal to concatinated path.
    public let path: Path
    public let typeName: String
    public let listKey: CacheKey?
    public let filterKeys: [String]?
    public let sortKeyFirst: String?
    public let sortKeySecond: String?
    public let sortKeyThird: String?
    
    public init(
        payload: Payload,
        cacheKey: CacheKey,
        path: Path,
        typeName: String,
        listKey: CacheKey?,
        filterKeys: [String]?,
        sortKeyFirst: String?,
        sortKeySecond: String?,
        sortKeyThird: String?
    ) {
        self.payload = payload
        self.cacheKey = cacheKey
        self.path = path
        self.typeName = typeName
        self.listKey = listKey
        self.filterKeys = filterKeys
        self.sortKeyFirst = sortKeyFirst
        self.sortKeySecond = sortKeySecond
        self.sortKeyThird = sortKeyThird
    }
}

/// A reference to a cache record.
public struct RecordReference: Equatable {
    public let key: CacheKey
    
    public init(key: CacheKey) {
        self.key = key
    }
    
    public init(record: CacheRecord) {
        self.init(key: record.cacheKey)
    }
}

extension CacheRecord.PayloadValue: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .string(let s):     return s
        case .number(let n):     return String(n)
        case .bool(let b):       return String(b)
        case .null:              return "null"
        case .array(let arr):    return String(reflecting: arr)
        case .reference(let ref):      return String(reflecting: ref)
        }
    }
}

/// Merge Record Sets.
extension Dictionary where Key == CacheKey, Value == CacheRecord {
    @discardableResult public mutating func merge(records: RecordSet) -> CacheKeyChangeSet {
        var changedKeys = CacheKeyChangeSet()
        
        for (_, record) in records {
            changedKeys.formUnion(self.merge(record: record))
        }
        
        return changedKeys
    }
    
    @discardableResult public mutating func merge(record: CacheRecord) -> CacheKeyChangeSet {
        if var oldRecord = self.removeValue(forKey: record.cacheKey) {
            var changedKeys = CacheKeyChangeSet()
            
            for (key, newValue) in record.payload {
                if let oldValue = oldRecord.payload[key], oldValue == newValue {
                    continue
                }
                oldRecord[key] = newValue
                // TODO: cacheKey construction will need to take arguments/directives/etc. into account
                // will need to include that here.
                changedKeys.insert([record.cacheKey, key].joined(separator: "."))
            }
            self[record.cacheKey] = oldRecord
            return changedKeys
        } else {
            self[record.cacheKey] = record
            return Set(record.payload.keys.map { [record.cacheKey, $0].joined(separator: ".") })
        }
    }
}
