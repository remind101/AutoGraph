import Foundation
import JSONValueRX

public enum MappingDirection {
    case fromJSON
    case toJSON
}

internal let CRMappingDomain = "CRMappingDomain"

public protocol Keypath: JSONKeypath { }

extension String: Keypath { }
extension Int: Keypath { }

open class MappingContext {
    open var json: JSONValue
    open var object: Any
    open fileprivate(set) var dir: MappingDirection
    open internal(set) var error: Error?
    open internal(set) var parent: MappingContext? = nil
    
    init(withObject object: Any, json: JSONValue, direction: MappingDirection) {
        self.dir = direction
        self.object = object
        self.json = json
    }
}

/// Method caller used to perform mappings.
public struct CRMapper<T, U: Mapping> where U.MappedObject == T {
    
    public init() { }
    
    public func mapFromJSONToNewObject(_ json: JSONValue, mapping: U) throws -> T {
        let object = try mapping.getNewInstance()
        return try mapFromJSON(json, toObject: object, mapping: mapping)
    }
    
    public func mapFromJSONToExistingObject(_ json: JSONValue, mapping: U, parentContext: MappingContext? = nil) throws -> T {
        var object = try mapping.getExistingInstance(json: json)
        if object == nil {
            object = try mapping.getNewInstance()
        }
        return try mapFromJSON(json, toObject: object!, mapping: mapping, parentContext: parentContext)
    }
    
    public func mapFromJSON(_ json: JSONValue, toObject object: T, mapping: U, parentContext: MappingContext? = nil) throws -> T {
        var object = object
        let context = MappingContext(withObject: object, json: json, direction: MappingDirection.fromJSON)
        context.parent = parentContext
        try mapping.performMappingWithObject(&object, context: context)
        return object
    }
    
    public func mapFromObjectToJSON(_ object: T, mapping: U) throws -> JSONValue {
        var object = object
        let context = MappingContext(withObject: object, json: JSONValue.object([:]), direction: MappingDirection.toJSON)
        try mapping.performMappingWithObject(&object, context: context)
        return context.json
    }
}

public extension Mapping {
    func getExistingInstance(json: JSONValue) throws -> MappedObject? {
        
        try self.checkForAdaptorBaseTypeConformance()
        
        guard let primaryKeys = self.primaryKeys else {
            return nil
        }
        
        var keyValues = [ String : CVarArg ]()
        try primaryKeys.forEach { primaryKey, jsonKey in
            let keyPath = jsonKey.keyPath
            if let val = json[keyPath] {
                keyValues[primaryKey] = val.valuesAsNSObjects()
            } else {
                let userInfo = [ NSLocalizedFailureReasonErrorKey : "Primary key of \(keyPath) does not exist in JSON but is expected from mapping \(Self.self)" ]
                throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
            }
        }
        
        let obj = self.adaptor.fetchObjects(type: MappedObject.self as! AdaptorKind.BaseType.Type, keyValues: keyValues)?.first
        return obj as! MappedObject?
    }
    
    func getNewInstance() throws -> MappedObject {
        
        try self.checkForAdaptorBaseTypeConformance()
        
        return try self.adaptor.createObject(type: MappedObject.self as! AdaptorKind.BaseType.Type) as! MappedObject
    }
    
    internal func checkForAdaptorBaseTypeConformance() throws {
        // NOTE: This sux but `MappedObject: AdaptorKind.BaseType` as a type constraint throws a compiler error as of 7.1 Xcode
        // and `MappedObject == AdaptorKind.BaseType` doesn't work with sub-types (i.e. expects MappedObject to be that exact type)
        
        guard MappedObject.self is AdaptorKind.BaseType.Type else {
            let userInfo = [ NSLocalizedFailureReasonErrorKey : "Type of object \(MappedObject.self) is not a subtype of \(AdaptorKind.BaseType.self)" ]
            throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
        }
    }
    
    internal func startMapping(context: MappingContext) throws {
        if context.parent == nil {
            var underlyingError: NSError?
            do {
                try self.adaptor.mappingBegins()
            } catch let err as NSError {    // We can handle NSErrors higher up.
                underlyingError = err
            } catch {
                var userInfo = [AnyHashable : Any]()
                userInfo[NSLocalizedFailureReasonErrorKey] = "Errored during mappingBegins for adaptor \(self.adaptor)"
                userInfo[NSUnderlyingErrorKey] = underlyingError
                throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
            }
        }
    }
    
    internal func endMapping(context: MappingContext) throws {
        if context.parent == nil {
            var underlyingError: NSError?
            do {
                try self.adaptor.mappingEnded()
            } catch let err as NSError {
                underlyingError = err
            } catch {
                var userInfo = [AnyHashable : Any]()
                userInfo[NSLocalizedFailureReasonErrorKey] = "Errored during mappingEnded for adaptor \(self.adaptor)"
                userInfo[NSUnderlyingErrorKey] = underlyingError
                throw NSError(domain: CRMappingDomain, code: -1, userInfo: userInfo)
            }
        }
    }
    
    public func executeMapping(object: inout MappedObject, context: MappingContext) {
        self.mapping(tomap: &object, context: context)
    }
    
    internal func performMappingWithObject(_ object: inout MappedObject, context: MappingContext) throws {
        
        try self.startMapping(context: context)
        
        self.executeMapping(object: &object, context: context)
        
        if context.error == nil {
            do {
                try self.checkForAdaptorBaseTypeConformance()
                try self.adaptor.save(objects: [ object as! AdaptorKind.BaseType ])
            } catch let error as NSError {
                context.error = error
            }
        }
        
        if let error = context.error {
            if context.parent == nil {
                self.adaptor.mappingErrored(error)
            }
            throw error
        }
        
        try self.endMapping(context: context)
        
        context.object = object
    }
}
