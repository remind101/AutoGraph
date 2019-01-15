import Foundation
import JSONValueRX

public typealias CacheKeyForObject = (_ payload: CacheRecord.Payload, _ objectField: Field, _ path: Path, _ variableValues: [AnyHashable : Any]) -> String

extension JSONValue: ResolvableValue {
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }
    
    public var asList: [JSONValue]? {
        guard case .array(let array) = self else { return nil }
        return array
    }
}

extension Optional: ResolvableValue where Wrapped: ResolvableValue {
    public var isNull: Bool {
        guard let wrapped = self else { return true }
        return wrapped.isNull
    }
    
    public var asList: [Optional<Wrapped>]? {
        guard let wrapped = self else { return nil }
        return wrapped.asList
    }
}

public struct JSONResponseResolver: Resolver {
    public func resolveFieldValue(
        field: Field,
        objectType: String,
        objectValue: JSONValue,
        fieldName: String,
        argumentValues: [AnyHashable : InputValue]
    ) throws -> JSONValue {
        guard let val = objectValue[field.responseKey] else { return .null }
        return val
    }
    
    public func objectValue(from value: JSONValue, field: Field) -> JSONValue? {
        guard case .object = value else {
            return nil
        }
        return value
    }
    
    public func scalarValue(from value: JSONValue, field: Field) -> ScalarValue? {
        switch value {
        case .bool(let bool):
            return .bool(bool)
        case .number(let double):
            // TODO: FieldType should carry actual type info so we know if Int or Float.
            if let int = Int64(exactly: double) {
                return .int(int)
            }
            else {
                return .float(double)
            }
        case .string(let string):
            return .string(string)
        case .null:
            return .null
        case .array, .object:
            return nil
        }
    }
}

public protocol Storage {
    func record(for cacheKey: String) -> CacheRecord?
    func record(for field: Field) -> CacheRecord?
}

public final class CacheResolver<_Storage: Storage>: Resolver {
    public enum Resolved: ResolvableValue {
        case payloadValue(CacheRecord.PayloadValue)
        case nextObject(CacheRecord.Payload, field: Field)
        
        public var isNull: Bool {
            guard case .payloadValue(.null) = self else { return false }
            return true
        }
        
        public var asList: [Resolved]? {
            guard case .payloadValue(.array(let list)) = self else { return nil }
            return list.map { .payloadValue($0) }
        }
    }
    
    public let storage: _Storage
    
    public init(storage: _Storage) {
        self.storage = storage
    }
    
    public func resolveFieldValue(
        field: Field,
        objectType: String,
        objectValue: CacheRecord.Payload,
        fieldName: String,
        argumentValues: [AnyHashable : InputValue]
    ) -> Resolved {
        guard let payloadValue = objectValue[field.responseKey] else { return .payloadValue(.null) }
        switch payloadValue {
        case .string, .number, .bool, .null, .array:
            return .payloadValue(payloadValue)
        case .reference(let reference):
            let storedRecord = self.storage.record(for: reference.key)
            guard let payload = storedRecord?.payload else {
                return .payloadValue(.null)
            }
            return .nextObject(payload, field: field)
        }
    }
    
    public func objectValue(from value: Resolved, field: Field) -> CacheRecord.Payload? {
        guard case .nextObject(let payload, _) = value else {
            return nil
        }
        return payload
    }
    
    public func scalarValue(from value: Resolved, field: Field) -> ScalarValue? {
        switch value {
        case .payloadValue(let payloadValue):
            switch payloadValue {
            case .bool(let bool):
                return .bool(bool)
            case .number(let double):
                // TODO: FieldType should carry actual type info so we know if Int or Float.
                if let int = Int64(exactly: double) {
                    return .int(int)
                }
                else {
                    return .float(double)
                }
            case .string(let string):
                return .string(string)
            case .null:
                return .null
            case .array, .reference:
                return nil
            }
        case .nextObject:
            return nil
        }
    }
}

// TODO: TBD
//public struct Watcher: ResolvableValue {}
//public struct WatcherResolver: Resolver {
//    public func resolveFieldValue(
//        field: Field,
//        objectType: String,
//        objectValue: JSONValue,
//        fieldName: String,
//        argumentValues: [AnyHashable : InputValue]
//    ) -> Watcher {
//        return Watcher()
//    }
//}

public final class CacheAccumulator<_Storage: Storage>: Accumulator {
    enum Err: LocalizedError {
        case listRecursionError(fieldResponseKey: String)
        
        var localizedDescription: String {
            switch self {
            case .listRecursionError(let fieldResponseKey):
                return "List recursion failer in CacheAccumulator for field \(fieldResponseKey)"
            }
        }
    }
    
    public private(set) var recordSet = RecordSet()
    public let storage: _Storage
    
    public init(storage: _Storage) {
        self.storage = storage
    }
    
    public var accumulatedResults: RecordSet {
        return self.recordSet
    }
    
    public func accumulate(
        responseKey: String,
        value: CompletedValue<[String : CacheResolver<_Storage>.Resolved]>,
        for field: Field,
        at path: Path,
        with variableValues: [AnyHashable : Any],
        cacheKeyFunc: CacheKeyForObject?
    ) throws -> CacheResolver<_Storage>.Resolved {
        switch value {
        case .scalar(let scalar):
            switch scalar {
            case .bool(let bool):       return .payloadValue(.bool(bool))
            case .float(let double):    return .payloadValue(.number(double))
            case .int(let int):         return .payloadValue(.number(Double(int)))
            case .string(let string):   return .payloadValue(.string(string))
            case .null:                 return .payloadValue(.null)
            }
        case .list(let list):
            // TODO: here is where you should special case for storing list edges.
            var resolvedList = [CacheRecord.PayloadValue]()
            resolvedList.reserveCapacity(list.count)
            for (index, element) in list.enumerated() {
                let nextPath = path + [index]
                let resolvedValue = try self.accumulate(responseKey: responseKey,
                                                        value: element,
                                                        for: field,
                                                        at: nextPath,
                                                        with: variableValues,
                                                        cacheKeyFunc: cacheKeyFunc)
                let payloadValue: CacheRecord.PayloadValue = try {
                    switch resolvedValue {
                    case .payloadValue(let payloadValue):
                        return payloadValue
                    case .nextObject:
                        // NOTE: Based on the structure of this recursion we should never actually reach this point.
                        throw Err.listRecursionError(fieldResponseKey: field.responseKey)
                    }
                }()
                resolvedList.append(payloadValue)
            }
            return .payloadValue(.array(resolvedList))
        case .object(let object):
            let record = try CacheRecord(resolvedValues: object, field: field, path: path, variableValues: variableValues, cacheKeyFunc: cacheKeyFunc)
            self.recordSet.merge(record: record)
            
            let reference = RecordReference(record: record)
            return .payloadValue(.reference(reference))
        case .null:
            return .payloadValue(.null)
        }
    }
}

extension CacheRecord {
    init<_Storage>(resolvedValues: [String : CacheResolver<_Storage>.Resolved], field: Field, path: Path, variableValues: [AnyHashable : Any], cacheKeyFunc: CacheKeyForObject?) throws {
        let payload = try resolvedValues.reduce(into: CacheRecord.Payload()) { (payload, element) in
            let (responseKey, resolvedValue) = element
            payload[responseKey] = try CacheRecord.PayloadValue(resolvedValue: resolvedValue, path: path, variableValues: variableValues, cacheKeyFunc: cacheKeyFunc)
        }
        
        let cacheKey = try path.cacheKey(payload: payload, field: field, variableValues: variableValues, cacheKeyFunc: cacheKeyFunc)
        // TODO: fix up speciliazed key stuff.
        self = CacheRecord(payload: payload, cacheKey: cacheKey, path: path, typeName: "TODO: field.typeName", listKey: nil, filterKeys: nil, sortKeyFirst: nil, sortKeySecond: nil, sortKeyThird: nil)
    }
}

extension CacheRecord.PayloadValue {
    init<_Storage>(resolvedValue: CacheResolver<_Storage>.Resolved, path: Path, variableValues: [AnyHashable : Any], cacheKeyFunc: CacheKeyForObject?) throws {
        switch resolvedValue {
        case .payloadValue(let payloadValue):
            self = payloadValue
        case .nextObject(let payload, let field): // Could optimize by dealing in CacheRecords instead of Payloads
            let nextPath: [PathComponent] = path + [field]
            let key = try nextPath.cacheKey(payload: payload, field: field, variableValues: variableValues, cacheKeyFunc: cacheKeyFunc)
            let ref = RecordReference(key: key)
            self = .reference(ref)
        }
    }
}
