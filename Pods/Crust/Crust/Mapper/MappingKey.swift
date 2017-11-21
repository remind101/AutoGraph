import Foundation
import JSONValueRX

enum CrustError: LocalizedError {
    case nestedCodingKeyError(type: Any.Type, keyPath: String)
    
    var errorDescription: String? {
        switch self {
        case .nestedCodingKeyError(let type, let keyPath):
            return "No nested coding key for type \(type) with keyPath \(keyPath)"
        }
    }
}

public protocol MappingKey: JSONKeyPath, DynamicMappingKey, Hashable {
    /// Return the collection of coding keys for a nested set of JSON. A non-nil value is required for every key
    /// that is used to key into JSON passed to a nested `Mapping`, otherwise the mapping operation
    /// for that nested type will fail and throw an error.
    ///
    /// - returns: Collection of MappingKeys for the nested JSON. `nil` on error - results in error during mapping.
    func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>?
}

public extension MappingKey {
    public var hashValue: Int {
        return self.keyPath.hashValue
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }
}

public protocol DynamicMappingKey {
    func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>?
}

// Use in place of `MappingKey` if the keys have no nested values.
public protocol RawMappingKey: MappingKey { }
extension RawMappingKey {
    public func nestedMappingKeys<K: MappingKey>() -> AnyKeyCollection<K>? {
        return nil
    }
}

public extension RawRepresentable where Self: MappingKey, RawValue == String {
    public var keyPath: String {
        return self.rawValue
    }
}

/// Use this as a key if you intend to map the whole json payload.
public struct RootKey: MappingKey {
    public let keyPath = ""
    public init() { }
    
    public func nestedMappingKeys<K: MappingKey>() -> AnyKeyCollection<K>? {
        return [self].anyKeyCollection()
    }
}

/// Like `RootKey` but will use the `nestedMappingKeys` of the internal key.
public struct RootedKey<K: MappingKey>: MappingKey {
    public let keyPath = ""
    public let rootedKey: K
    public init(_ rootedKey: K) {
        self.rootedKey = rootedKey
    }
    
    public func nestedMappingKeys<K: MappingKey>() -> AnyKeyCollection<K>? {
        return self.rootedKey.nestedMappingKeys()
    }
}

extension String: RawMappingKey { }

extension Int: RawMappingKey { }

public struct AnyMappingKey: MappingKey, ExpressibleByStringLiteral {
    public var hashValue: Int {
        return _hashValue()
    }
    private let _hashValue: () -> Int
    
    public var keyPath: String {
        return _keyPath()
    }
    private let _keyPath: () -> String
    
    public let type: Any.Type
    public let base: DynamicMappingKey
    
    public init<K>(_ base: K) where K: MappingKey {
        self.base = base
        self.type = K.self
        self._keyPath = { base.keyPath }
        self._hashValue = { base.hashValue }
    }
    
    public func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>? {
        return self.base.nestedMappingKeys()
    }
    
    public typealias UnicodeScalarLiteralType = StringLiteralType
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

public protocol KeyCollection: DynamicKeyCollection {
    associatedtype MappingKeyType: MappingKey
    
    init<Source>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == MappingKeyType
    func containsKey(_ key: MappingKeyType) -> Bool
    func nestedKeyCollection<Key: MappingKey>(`for` key: MappingKeyType) -> AnyKeyCollection<Key>?
}

public extension KeyCollection {
    public func nestedDynamicKeyCollection<Key: MappingKey>(`for` key: Any) -> AnyKeyCollection<Key>? {
        guard case let key as MappingKeyType = key else {
            return nil
        }
        return self.nestedKeyCollection(for: key)
    }
    
    public func anyKeyCollection<TargetKey: MappingKey>() -> AnyKeyCollection<TargetKey>? {
        return AnyKeyCollection(self) as? AnyKeyCollection<TargetKey>
    }
    
    func nestedKeyCollection<Key: MappingKey>(`for` key: MappingKeyType) throws -> AnyKeyCollection<Key> {
        guard let nested = (self.nestedKeyCollection(for: key) as AnyKeyCollection<Key>?) else {
            throw CrustError.nestedCodingKeyError(type: MappingKeyType.self, keyPath: key.keyPath)
        }
        return nested
    }
}

/// This exists to get around the fact that `AnyKeyCollection` cannot capture `nestedKeyCollection<K: MappingKey>` in a closure.
public protocol DynamicKeyCollection {
    /// This exists to get around the fact that `AnyKeyCollection` cannot capture `nestedKeyCollection<K: MappingKey>` in a closure.
    /// This is automatically implemented for `KeyCollection`.
    func nestedDynamicKeyCollection<Key: MappingKey>(`for` key: Any) -> AnyKeyCollection<Key>?
}

public struct AnyKeyCollection<K: MappingKey>: KeyCollection {
    public let mappingKeyType: K.Type
    public let keyCollectionType: Any.Type
    private let _containsKey: (K) -> Bool
    private let dynamicKeyCollection: DynamicKeyCollection
    
    public init?(_ anyMappingKeyKeyCollection: AnyMappingKeyKeyCollection) {
        guard case let mappingKeyType as K.Type = anyMappingKeyKeyCollection.mappingKeyType else {
            return nil
        }
        
        self.keyCollectionType = anyMappingKeyKeyCollection.keyCollectionType
        self.mappingKeyType = mappingKeyType
        self._containsKey = { key in
            return anyMappingKeyKeyCollection.containsKey(key)
        }
        self.dynamicKeyCollection = anyMappingKeyKeyCollection
    }
    
    public init(_ keyCollection: AnyKeyCollection<K>) {
        self = keyCollection
    }
    
    public init<P: KeyCollection>(_ keyCollection: P) where P.MappingKeyType == K {
        self.keyCollectionType = P.self
        self.mappingKeyType = K.self
        self._containsKey = { key in
            return keyCollection.containsKey(key)
        }
        self.dynamicKeyCollection = keyCollection
    }
    
    public init(arrayLiteral elements: K...) {
        let keyCollection = SetKeyCollection(Set(elements))
        self.keyCollectionType = type(of: keyCollection).self
        self.mappingKeyType = K.self
        self._containsKey = { key in
            return keyCollection.containsKey(key)
        }
        self.dynamicKeyCollection = keyCollection
    }
    
    public init<Source>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == (K) {
        let keyCollection = SetKeyCollection(Set(sequence))
        self.keyCollectionType = type(of: keyCollection).self
        self.mappingKeyType = K.self
        self._containsKey = { key in
            return keyCollection.containsKey(key)
        }
        self.dynamicKeyCollection = keyCollection
    }
    
    public func containsKey(_ key: K) -> Bool {
        return self._containsKey(key)
    }
    
    public func nestedKeyCollection<Key: MappingKey>(for key: K) -> AnyKeyCollection<Key>? {
        return self.dynamicKeyCollection.nestedDynamicKeyCollection(for: key)
    }
}

public struct AnyMappingKeyKeyCollection: KeyCollection {
    public let mappingKeyType: Any.Type
    public let keyCollectionType: Any.Type
    private let _containsKey: (Any) -> Bool
    private let dynamicKeyCollection: DynamicKeyCollection
    
    public init<P: KeyCollection>(_ keyCollection: P) {
        self.mappingKeyType = P.MappingKeyType.self
        self._containsKey = { key in
            guard case let key as P.MappingKeyType = key else {
                return false
            }
            return keyCollection.containsKey(key)
        }
        self.keyCollectionType = P.self
        self.dynamicKeyCollection = keyCollection
    }
    
    public init(_ anyMappingKeyKeyCollection: AnyMappingKeyKeyCollection) {
        self = anyMappingKeyKeyCollection
    }
    
    public init<Source, KeyType: MappingKey>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == (KeyType) {
        let keyCollection = SetKeyCollection(Set(sequence))
        self.mappingKeyType = KeyType.self
        self._containsKey = { key in
            guard case let key as KeyType = key else {
                return false
            }
            return keyCollection.containsKey(key)
        }
        self.keyCollectionType = SetKeyCollection<KeyType>.self
        self.dynamicKeyCollection = keyCollection
    }
    
    public func containsKey(_ key: AnyMappingKey) -> Bool {
        return self._containsKey(key)
    }
    
    public func containsKey<K: MappingKey>(_ key: K) -> Bool {
        return self._containsKey(key)
    }
    
    public func nestedKeyCollection<Key: MappingKey>(for key: AnyMappingKey) -> AnyKeyCollection<Key>? {
        return self.dynamicKeyCollection.nestedDynamicKeyCollection(for: key.base)
    }
}

public struct AllKeys<K: MappingKey>: KeyCollection {
    public init() {}
    public init(arrayLiteral elements: K...) { }
    public init<Source>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == (K) { }
    
    public func containsKey(_ key: K) -> Bool {
        return true
    }
    
    public func nestedKeyCollection<Key: MappingKey>(for key: K) -> AnyKeyCollection<Key>? {
        return AnyKeyCollection(AllKeys<Key>())
    }
}

/// A `Set` of `MappingKey`s.
///
/// TODO: Can make Set follow `KeyCollection` protocol once conditional conformances are available in Swift 4.1
/// https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md .
public struct SetKeyCollection<K: MappingKey>: KeyCollection, ExpressibleByArrayLiteral {
    public let keys: Set<K>
    
    public init(_ keys: Set<K>) {
        self.keys = keys
    }
    
    public init<Source>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == (K) {
        self.keys = Set(sequence)
    }
    
    public init(arrayLiteral elements: K...) {
        self.keys = Set(elements)
    }
    
    public init(array: [K]) {
        self.keys = Set(array)
    }
    
    public func containsKey(_ key: K) -> Bool {
        return self.keys.contains(key)
    }
    
    public func nestedKeyCollection<Key: MappingKey>(for key: K) -> AnyKeyCollection<Key>? {
        guard let index = self.keys.index(of: key) else {
            return nil
        }
        let key = self.keys[index]
        return key.nestedMappingKeys()
    }
}

internal struct NestedMappingKey<RootKey: MappingKey, NestedCollection: KeyCollection>: MappingKey, KeyCollection {
    let rootKey: RootKey
    let nestedKeys: NestedCollection
    
    var keyPath: String {
        return self.rootKey.keyPath
    }
    
    init(rootKey: RootKey, nestedKeys: NestedCollection) {
        self.rootKey = rootKey
        self.nestedKeys = nestedKeys
    }
    
    // NOTE: cannot mark @available(*, unavailable) in Swift 4.
    init<Source>(_ sequence: Source) where Source : Sequence, Source.Iterator.Element == (RootKey) {
        fatalError("Don't use this.")
    }
    
    func containsKey(_ key: RootKey) -> Bool {
        return key == rootKey
    }
    
    func nestedKeyCollection<Key: MappingKey>(for key: RootKey) -> AnyKeyCollection<Key>? {
        return AnyKeyCollection(self.nestedKeys) as? AnyKeyCollection<Key>
    }
    
    func nestedMappingKeys<Key: MappingKey>() -> AnyKeyCollection<Key>? {
        return AnyKeyCollection(self.nestedKeys) as? AnyKeyCollection<Key>
    }
}

internal struct KeyedBinding<K: MappingKey, M: Mapping> {
    public let binding: Binding<K, M>
    public let codingKeys: AnyKeyCollection<M.MappingKeyType>
    
    public init<KC: KeyCollection>(binding: Binding<K, M>, codingKeys: KC) where KC.MappingKeyType == M.MappingKeyType {
        self.binding = binding
        self.codingKeys = AnyKeyCollection(codingKeys)
    }
    
    public init(binding: Binding<K, M>, codingKeys: AnyKeyCollection<M.MappingKeyType>) {
        self.binding = binding
        self.codingKeys = codingKeys
    }
    
    public init?(binding: Binding<K, M>, payload: MappingPayload<K>) throws {
        guard payload.keys.containsKey(binding.key) else {
            return nil
        }
        
        let codingKeys: AnyKeyCollection<M.MappingKeyType> = try {
            if M.MappingKeyType.self is RootKey.Type {
                return AnyKeyCollection([RootKey() as! M.MappingKeyType])
            }
            
            return try payload.keys.nestedKeyCollection(for: binding.key)
        }()
        
        self.init(binding: binding, codingKeys: codingKeys)
    }
    
    init?<BindingK>(binding: Binding<RootedKey<BindingK>, M>, payload: MappingPayload<BindingK>) throws where K == RootKey {
        let rootedKey = binding.key.rootedKey
        guard payload.keys.containsKey(rootedKey) else {
            return nil
        }
        
        let binding: Binding<RootKey, M> = {
            switch binding {
            case .mapping(_, let mapping):
                return .mapping(RootKey(), mapping)
            case .collectionMapping(_, let mapping, let updatePolicy):
                return .collectionMapping(RootKey(), mapping, updatePolicy)
            }
        }()
        
        let codingKeys: AnyKeyCollection<M.MappingKeyType> = try payload.keys.nestedKeyCollection(for: rootedKey)
        self.init(binding: binding, codingKeys: codingKeys)
    }
}
