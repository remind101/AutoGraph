import Foundation
import JSONValueRX

/// Defines a type which can be converted to a GraphQL string. This includes queries and fragments.
public protocol QueryConvertible {
    func graphQLString() throws -> String
}

/// Defines a _Field_ from the GraphQL language. Inherited by `Object` and `Scalar`.
public protocol Field: QueryConvertible {
    var name: String { get }
    var alias: String? { get }
    func serializedAlias() throws -> String
}

public extension Field {
    func serializedAlias() throws -> String {
        guard let alias = self.alias else {
            return ""
        }
        return "\(alias.withoutWhitespace): "
    }
}

/// Any type that accepts `Field`s. Inherited by `AcceptsSelectionSet`.
public protocol AcceptsFields {
    var fields: [Field]? { get }
    func serializedFields() throws -> String
}

public extension AcceptsFields {
    func serializedFields() throws -> String {
        guard let fields = self.fields else {
            return ""
        }
        
        let fieldsList = try fields.map { try $0.graphQLString() }.joined(separator: "\n")
        return fieldsList
    }
}

/// `Fragment` can be used as both a _FragmentDefinition_ and a _FragmentSpread_ from the
/// GraphQL language. Accepted as by any type which inherits `AcceptsSelectionSet`.
public struct Fragment: AcceptsSelectionSet, QueryConvertible {
    public let name: String
    public let type: String
    public let fields: [Field]?
    public let fragments: [Fragment]?
    
    public init?(name: String, type: String, fields: [Field]? = nil, fragments: [Fragment]? = nil) {
        guard name != "on" else {
            return nil
        }
        guard fields?.count ?? 0 > 0 || fragments?.count ?? 0 > 0 else {
            return nil
        }
        self.name = name
        self.type = type
        self.fields = fields
        self.fragments = fragments
    }
    
    public func graphQLString() throws -> String {
        return "fragment \(self.name) on \(self.type)\(try self.serializedSelectionSet())"
    }
}

/// Any type that accepts a _SelectionSet_ from the GraphQL Language.
///
/// This type must accept `Field`s and `Fragment`s and must include either a set of
/// `fragments` _(FragmentSpread)_ or a set of `fields` or both.
public protocol AcceptsSelectionSet: AcceptsFields {
    var fields: [Field]? { get }
    var fragments: [Fragment]? { get }
    func serializedFragments() throws -> String
    func serializedSelectionSet() throws -> String
}

public extension AcceptsSelectionSet {
    public func serializedSelectionSet() throws -> String {
        let fields = try self.serializedFields()
        let fragments = try self.serializedFragments()
        let selectionSet = [fields, fragments].flatMap { selection -> String? in
            guard selection.characters.count > 0 else {
                return nil
            }
            return selection
        }.joined(separator: "\n")
        
        guard selectionSet.characters.count > 0 else {
            return ""
        }
        
        return " {\n\(selectionSet)\n}"
    }
    
    public func serializedFragments() throws -> String {
        guard let fragments = self.fragments else {
            return ""
        }
        
        let fragmentsList = fragments.map { "...\($0.name)" }.joined(separator: "\n")
        return fragmentsList
    }
}

/// Any type which inherits `InputValue` can be used as an Input Value (_Value_ and _InputObjectValue_) from the GraphQL language.
///
/// Inherited by `String`, `Int`, `UInt`, `Double`, `Bool`, `Float`, `NSNull`, `NSNumber`, `Array`, and `Dictionary`
/// by default.
public protocol InputValue {
    func graphQLInputValue() throws -> String
}

/// Any type that accepts _Arguments_ from the GraphQL language.
public protocol AcceptsArguments {
    var arguments: [String : InputValue]? { get }
    func serializedArguments() throws -> String
}

public extension AcceptsArguments {
    func serializedArguments() throws -> String {
        
        guard let arguments = self.arguments else {
            return ""
        }
        
        let argumentsList = try arguments.map { (key, value) in
            "\(key): \(try value.graphQLInputValue())"
        }.joined(separator: ", ")
        
        return "(\(argumentsList))"
    }
}

/// Represents a `Field` which is a scalar type. Such types are Int, String, Bool, Null, List of Scalars, Enum, etc.
public struct Scalar: Field {
    public let name: String
    public let alias: String?
    
    public init(name: String, alias: String? = nil) {
        self.name = name
        self.alias = alias
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)"
    }
}

/// Represents a `Field` which is an object type in the schema.
public struct Object: Field, AcceptsArguments, AcceptsSelectionSet {
    public let name: String
    public let alias: String?
    public let fields: [Field]?
    public let fragments: [Fragment]?
    public let arguments: [String : InputValue]?
    
    public init(name: String, alias: String? = nil, fields: [Field]? = nil, fragments: [Fragment]? = nil, arguments: [String : InputValue]? = nil) {
        self.name = name
        self.alias = alias
        self.fields = fields
        self.fragments = fragments
        self.arguments = arguments
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)\(try self.serializedArguments())\(try self.serializedSelectionSet())"
    }
}

/// Represents a GraphQL query sent by a request to the server.
public protocol GraphQLQuery: QueryConvertible { }

/// Defines an _OperationDefinition_ from the GraphQL language. Generally used as the `query` portion of a GraphQL request.
public struct Operation: GraphQLQuery, AcceptsSelectionSet, AcceptsArguments {
    
    /// Defines an _OperationType_ from the GraphQL language.
    public enum OperationType: QueryConvertible {
        case query
        case mutation
        
        public func graphQLString() throws -> String {
            switch self {
            case .query:
                return "query"
            case .mutation:
                return "mutation"
            }
        }
    }
    
    public let type: OperationType
    public let name: String
    public let fields: [Field]?
    public let fragments: [Fragment]?
    public let arguments: [String : InputValue]?
    
    public init(type: OperationType, name: String, fields: [Field]? = nil, fragments: [Fragment]? = nil, arguments: [String : InputValue]? = nil) {
        self.type = type
        self.name = name
        self.fields = fields
        self.fragments = fragments
        self.arguments = arguments
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.type.graphQLString()) \(self.name)\(try self.serializedArguments())\(try self.serializedSelectionSet())"
    }
}
