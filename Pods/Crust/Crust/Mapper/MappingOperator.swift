import Foundation
import JSONValueRX

// MARK: - Merge right into tuple operator definition

infix operator >*< : AssignmentPrecedence

public func >*< <T, U>(left: T, right: U) -> (T, U) {
    return (left, right)
}

public func >*< <T: JSONKeypath, U>(left: T, right: U) -> (JSONKeypath, U) {
    return (left, right)
}

// MARK: - Map value operator definition

infix operator <- : AssignmentPrecedence

// Map arbitrary object.

@discardableResult
public func <- <T: JSONable, C: MappingContext>(field: inout T, map:(key: JSONKeypath, context: C)) -> C where T == T.ConversionType {
    return mapField(&field, map: map)
}

// Map a Mappable.

@discardableResult
public func <- <T, U: Mapping, C: MappingContext>(field: inout T, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T {
    return mapFieldWithMapping(&field, map: map)
}

@discardableResult
public func <- <T: JSONable, U: Transform, C: MappingContext>(field: inout T, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T, T == T.ConversionType {
    return mapFieldWithMapping(&field, map: map)
}

// NOTE: Must supply two separate versions for optional and non-optional types or we'll have to continuously
// guard against unsafe nil assignments.

@discardableResult
public func <- <T: JSONable, C: MappingContext>(field: inout T?, map:(key: JSONKeypath, context: C)) -> C where T == T.ConversionType {
    return mapField(&field, map: map)
}

@discardableResult
public func <- <T, U: Mapping, C: MappingContext>(field: inout T?, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T {
    return mapFieldWithMapping(&field, map: map)
}

@discardableResult
public func <- <T: JSONable, U: Transform, C: MappingContext>(field: inout T?, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T, T == T.ConversionType {
    return mapFieldWithMapping(&field, map: map)
}

// MARK: - Map funcs

// Arbitrary object.
public func mapField<T: JSONable, C: MappingContext>(_ field: inout T, map:(key: JSONKeypath, context: C)) -> C where T == T.ConversionType {
    
    guard map.context.error == nil else {
        return map.context
    }
    
    switch map.context.dir {
    case .toJSON:
        let json = map.context.json
        map.context.json = mapToJson(json, fromField: field, viaKey: map.key)
    case .fromJSON:
        do {
            if let baseJSON = map.context.json[map.key] {
                try mapFromJson(baseJSON, toField: &field)
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "Could not find value in JSON \(map.context.json) from keyPath \(map.key)" ]
                throw NSError(domain: CRMappingDomain, code: 0, userInfo: userInfo)
            }
        } catch let error as NSError {
            map.context.error = error
        }
    }
    
    return map.context
}

// Arbitrary Optional.
public func mapField<T: JSONable, C: MappingContext>(_ field: inout T?, map:(key: JSONKeypath, context: C)) -> C where T == T.ConversionType {
    
    guard map.context.error == nil else {
        return map.context
    }
    
    switch map.context.dir {
    case .toJSON:
        let json = map.context.json
        map.context.json = mapToJson(json, fromField: field, viaKey: map.key)
    case .fromJSON:
        do {
            if let baseJSON = map.context.json[map.key] {
                try mapFromJson(baseJSON, toField: &field)
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "Value not present in JSON \(map.context.json) from keyPath \(map.key)" ]
                throw NSError(domain: CRMappingDomain, code: 0, userInfo: userInfo)
            }
        } catch let error as NSError {
            map.context.error = error
        }
    }
    
    return map.context
}

// Mappable.
public func mapFieldWithMapping<T, U: Mapping, C: MappingContext>(_ field: inout T, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T {
    
    guard map.context.error == nil else {
        return map.context
    }
    
    guard case .mapping(let key, let mapping) = map.key else {
        let userInfo = [ NSLocalizedFailureReasonErrorKey : "Expected KeyExtension.mapping to map type \(T.self)" ]
        map.context.error = NSError(domain: CRMappingDomain, code: -1000, userInfo: userInfo)
        return map.context
    }
    
    do {
        switch map.context.dir {
        case .toJSON:
            let json = map.context.json
            try map.context.json = mapToJson(json, fromField: field, viaKey: key, mapping: mapping)
        case .fromJSON:
            if let baseJSON = map.context.json[map.key] {
                try mapFromJson(baseJSON, toField: &field, mapping: mapping, context: map.context)
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "JSON at key path \(map.key) does not exist to map from" ]
                throw NSError(domain: CRMappingDomain, code: 0, userInfo: userInfo)
            }
        }
    } catch let error as NSError {
        map.context.error = error
    }
    
    return map.context
}

// TODO: Maybe we can just make Optional: Mappable and then this redudancy can safely go away...
public func mapFieldWithMapping<T, U: Mapping, C: MappingContext>(_ field: inout T?, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T {
    
    guard map.context.error == nil else {
        return map.context
    }
    
    guard case .mapping(let key, let mapping) = map.key else {
        let userInfo = [ NSLocalizedFailureReasonErrorKey : "Expected KeyExtension.mapping to map type \(T.self)" ]
        map.context.error = NSError(domain: CRMappingDomain, code: -1000, userInfo: userInfo)
        return map.context
    }
    
    do {
        switch map.context.dir {
        case .toJSON:
            let json = map.context.json
            try map.context.json = mapToJson(json, fromField: field, viaKey: key, mapping: mapping)
        case .fromJSON:
            if let baseJSON = map.context.json[map.key] {
                try mapFromJson(baseJSON, toField: &field, mapping: mapping, context: map.context)
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "JSON at key path \(map.key) does not exist to map from" ]
                throw NSError(domain: CRMappingDomain, code: 0, userInfo: userInfo)
            }
        }
    } catch let error as NSError {
        map.context.error = error
    }
    
    return map.context
}

// MARK: - To JSON

private func mapToJson<T: JSONable>(_ json: JSONValue, fromField field: T?, viaKey key: JSONKeypath) -> JSONValue where T == T.ConversionType {
    var json = json
    
    if let field = field {
        json[key] = T.toJSON(field)
    } else {
        json[key] = .null()
    }
    
    return json
}

private func mapToJson<T, U: Mapping>(_ json: JSONValue, fromField field: T?, viaKey key: Keypath, mapping: U) throws -> JSONValue where U.MappedObject == T {
    var json = json
    
    guard let field = field else {
        json[key] = .null()
        return json
    }
    
    json[key] = try CRMapper<T, U>().mapFromObjectToJSON(field, mapping: mapping)
    return json
}

// MARK: - From JSON

private func mapFromJson<T: JSONable>(_ json: JSONValue, toField field: inout T) throws where T.ConversionType == T {
    
    if let fromJson = T.fromJSON(json) {
        field = fromJson
    } else {
        let userInfo = [ NSLocalizedFailureReasonErrorKey : "Conversion of JSON \(json) to type \(T.self) failed" ]
        throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
    }
}

private func mapFromJson<T: JSONable>(_ json: JSONValue, toField field: inout T?) throws where T.ConversionType == T {
    
    if case .null = json {
        field = nil
        return
    }
    
    if let fromJson = T.fromJSON(json) {
        field = fromJson
    } else {
        let userInfo = [ NSLocalizedFailureReasonErrorKey : "Conversion of JSON \(json) to type \(T.self) failed" ]
        throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
    }
}

private func mapFromJson<T, U: Mapping>(_ json: JSONValue, toField field: inout T, mapping: U, context: MappingContext) throws where U.MappedObject == T {
    
    let mapper = CRMapper<T, U>()
    field = try mapper.mapFromJSONToExistingObject(json, mapping: mapping, parentContext: context)
}

private func mapFromJson<T, U: Mapping>(_ json: JSONValue, toField field: inout T?, mapping: U, context: MappingContext) throws where U.MappedObject == T {
    
    if case .null = json {
        field = nil
        return
    }
    
    let mapper = CRMapper<T, U>()
    field = try mapper.mapFromJSONToExistingObject(json, mapping: mapping, parentContext: context)
}

// MARK: - Appendable - RangeReplaceableCollectionType subset (Array and Realm List follow this protocol)

public protocol Appendable: Sequence {
    mutating func append(_ newElement: Self.Iterator.Element)
    mutating func append(contentsOf newElements: [Iterator.Element])
}

extension Array: Appendable { }

public func <- <T, U: Mapping, V: RangeReplaceableCollection, C: MappingContext>(field: inout V, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T, V.Iterator.Element == T, T: Equatable {
    
    return mapCollectionField(&field, map: map)
}

public func mapCollectionField<T, U: Mapping, V: RangeReplaceableCollection, C: MappingContext>(_ field: inout V, map:(key: Spec<U>, context: C)) -> C where U.MappedObject == T, V.Iterator.Element == T, T: Equatable {
    
    guard map.context.error == nil else {
        return map.context
    }
    
    let mapping = map.key.mapping
    do {
        switch map.context.dir {
        case .toJSON:
            let json = map.context.json
            try map.context.json = mapToJson(json, fromField: field, viaKey: map.key, mapping: mapping)
        case .fromJSON:
            if let baseJSON = map.context.json[map.key] {
                let allowDupes = map.key.options.contains(.AllowDuplicatesInCollection)
                try mapFromJson(baseJSON, toField: &field, mapping: mapping, context: map.context, allowDuplicates: allowDupes)
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "JSON at key path \(map.key) does not exist to map from" ]
                throw NSError(domain: CRMappingDomain, code: 0, userInfo: userInfo)
            }
        }
    } catch let error as NSError {
        map.context.error = error
    }
    
    return map.context
}

private func mapToJson<T, U: Mapping, V: RangeReplaceableCollection>(_ json: JSONValue, fromField field: V, viaKey key: Keypath, mapping: U) throws -> JSONValue where U.MappedObject == T, V.Iterator.Element == T {
    var json = json
    
    let results = try field.map {
        try CRMapper<T, U>().mapFromObjectToJSON($0, mapping: mapping)
    }
    json[key] = .array(results)
    
    return json
}

private func mapFromJson<T, U: Mapping, V: RangeReplaceableCollection>(_ json: JSONValue, toField field: inout V, mapping: U, context: MappingContext, allowDuplicates: Bool) throws where U.MappedObject == T, V.Iterator.Element == T, T: Equatable {
    
    if case .array(let xs) = json {
        let mapper = CRMapper<T, U>()
        var results = [T]()
        for x in xs {
            if !allowDuplicates {
                if let obj = try mapping.getExistingInstance(json: x) {
                    if results.contains(obj) {
                        continue
                    }
                }
            }
            
            let obj = try mapper.mapFromJSONToExistingObject(x, mapping: mapping, parentContext: context)
            results.append(obj)
        }
        field.append(contentsOf: results)
    } else {
        let userInfo = [ NSLocalizedFailureReasonErrorKey : "Trying to map json of type \(type(of: json)) to \(V.self)<\(T.self)>" ]
        throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
    }
}
