import Foundation
import JSONValueRX

/// Defines a type which can be converted to a GraphQL string. This includes queries and fragments.
public protocol QueryConvertible {
    func graphQLString() throws -> String
}

/// Defines a _Field_ from the GraphQL language. Inherited by `Object` and `Scalar`.
public protocol Field: AcceptsDirectives, QueryConvertible {
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

/// Defines a _FragmentSpread_ from the GraphQL language. Must reference a `fragmentDefinition`.
/// Accepted by any type which inherits `AcceptsSelectionSet`.
public struct FragmentSpread: AcceptsDirectives {
    public let fragment: FragmentDefinition
    public let directives: [Directive]?
    
    public init(fragment: FragmentDefinition, directives: [Directive]? = nil) {
        self.fragment = fragment
        self.directives = directives
    }
    
    public init?(name: String, type: String, directives: [Directive]? = nil) {
        guard let fragment = FragmentDefinition(name: name, type: type) else {
            return nil
        }
        self.fragment = fragment
        self.directives = directives
    }
}

/// Defines a _FragmentDefinition_ from the GraphQL language.
public struct FragmentDefinition: AcceptsSelectionSet, AcceptsDirectives, QueryConvertible {
    public let name: String
    public let type: String
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let directives: [Directive]?
    
    public init?(name: String, type: String, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, directives: [Directive]? = nil) {
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
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "fragment \(self.name) on \(self.type)\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}

/// Any type that accepts a _SelectionSet_ from the GraphQL Language.
///
/// This type must accept `Field`s and `Fragment`s and must include either a set of
/// `fragments` _(FragmentSpread)_ or a set of `fields` or both.
public protocol AcceptsSelectionSet: AcceptsFields {
    var name: String { get }
    var fields: [Field]? { get }
    var fragments: [FragmentSpread]? { get }
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
            throw QueryBuilderError.missingFields(selectionSetName: self.name)
        }
        
        return " {\n\(selectionSet)\n}"
    }
    
    public func serializedFragments() throws -> String {
        guard let fragments = self.fragments else {
            return ""
        }
        
        let fragmentsList = try fragments.map { "...\($0.fragment.name)\(try $0.serializedDirectives())" }.joined(separator: "\n")
        return fragmentsList
    }
}

/// Represents the names of types accepted by `InputValue`.
public indirect enum InputType {
    public enum ScalarTypes: String {
        case int = "Int"
        case float = "Float"
        case string = "String"
        case boolean = "Boolean"
        case null = "Null"
        case id = "ID"
    }
    
    case variable(typeName: String)
    case scalar(ScalarTypes)
    case nonNull(InputType)
    case list(InputType)
    case enumValue(typeName: String)
    case object(typeName: String)
    
    public var typeName: String {
        switch self {
        case .variable(let typeName):
            return typeName
        case .scalar(let type):
            return type.rawValue
        case .nonNull(let inputType):
            return inputType.typeName + "!"
        case .list(let inputType):
            return "[" + inputType.typeName + "]"
        case .enumValue(let typeName):
            return typeName
        case .object(let typeName):
            return typeName
        }
    }
}

/// Any type which inherits `InputValue` can be used as an Input Value (_Value_ and _InputObjectValue_) from the GraphQL language.
///
/// Inherited by `String`, `Int`, `UInt`, `Double`, `Bool`, `Float`, `NSNull`, `NSNumber`, `Array`, and `Dictionary`
/// by default.
public protocol InputValue {
    static func inputType() throws -> InputType
    func graphQLInputValue() throws -> String
}

/// Defines an _ObjectValue_ from the GraphQL language. Use this in replace of `Dictionary` when creating an `InputValue`
/// which will be represented by a `VariableDefinition`.
///
/// E.g. mutation:
///
/// ```
/// mutation UserProfileUpdate($profileUpdate: ProfileUpdate) {
///   user(profileUpdate: $profileUpdate)
/// }
/// ```
///
/// ProfileUpdate is a _Type_ Name that cannot be expressed merely by using a `Dictionary`.
/// 
/// When we construct our `VariableDefinition` for `$profileUpdate` it will be required that we use
/// `InputObjectValue` instead of a `Dictionary` for `<T: InputValue>` and specify `"ProfileUpdate"` for `objectTypeName: String`.
public protocol InputObjectValue: InputValue {
    static var objectTypeName: String { get }
    var fields: [String : InputValue] { get }
}

public extension InputObjectValue {
    static func inputType() throws -> InputType {
        return .object(typeName: self.objectTypeName)
    }
    
    func graphQLInputValue() throws -> String {
        return try self.fields.graphQLInputValue()
    }
}

/// `InputValue` representing an _ID_.
public struct IDValue: InputValue {
    let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public init(_ value: Int) {
        self.value = String(value)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.value.jsonEncodedString()
    }
    
    public static func inputType() throws -> InputType {
        return .scalar(.id)
    }
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

/// Use in order to specify that the type of an `InputValue` is _NonNullType_.
public struct NonNullInputValue<T: InputValue>: InputValue {
    public static func inputType() throws -> InputType {
        return .nonNull(try T.inputType())
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.inputValue.graphQLInputValue()
    }

    let inputValue: T
    
    init(inputValue: T) {
        self.inputValue = inputValue
    }
}

internal protocol VariableDefinitionType { }

/// Defines a _VariableDefinition_ from the GraphQL language.
public struct VariableDefinition<T: InputValue>: InputValue, VariableDefinitionType {
    public static func inputType() throws -> InputType {
        return try T.inputType()
    }
    
    public func graphQLInputValue() throws -> String {
        return "$" + self.name
    }
    
    public let name: String
    public let defaultValue: T?
    
    public init(name: String, defaultValue: T? = nil) {
        self.name = name
        self.defaultValue = defaultValue
    }
    
    public func typeErase() throws -> AnyVariableDefinition {
        return try AnyVariableDefinition(variableDefinition: self)
    }
}

public struct AnyVariableDefinition {
    public let name: String
    public let typeName: InputType
    public let defaultValue: InputValue?
    
    public init<T: InputValue>(variableDefinition: VariableDefinition<T>) throws {
        if variableDefinition.defaultValue is VariableDefinitionType {
            throw QueryBuilderError.incorrectInputType(message: "A VariableDefinition cannot use a default value of another VariableDefinition")
        }
        
        self.name = variableDefinition.name
        self.typeName = try T.inputType()
        self.defaultValue = variableDefinition.defaultValue
    }
}

/// Any type that accepts _VariableDefinition_ from the GraphQL language.
public protocol AcceptsVariableDefinitions {
    var variableDefinitions: [AnyVariableDefinition]? { get }
    func serializedVariableDefinitions() throws -> String
}

public extension AcceptsVariableDefinitions {
    func serializedVariableDefinitions() throws -> String {
        
        guard let variableDefinitions = self.variableDefinitions else {
            return ""
        }
        
        let defList: String = try variableDefinitions.map { def in
            let defaultValue: String = try {
                guard let defaultValue = def.defaultValue else {
                    return ""
                }
                
                if defaultValue is VariableDefinitionType {
                    throw QueryBuilderError.incorrectInputType(message: "A VariableDefinition cannot use a default value of another VariableDefinition")
                }
                
                return " = " + (try defaultValue.graphQLInputValue())
            }()
            
            return "$" + def.name + ": " + def.typeName.typeName + defaultValue
        }
        .joined(separator: ", ")
        
        return "(\(defList))"
    }
}

/// Represents a `Field` which is a scalar type. Such types are Int, String, Bool, Null, List of Scalars, Enum, etc.
public struct Scalar: Field {
    public let name: String
    public let alias: String?
    public let directives: [Directive]?
    
    public init(name: String, alias: String? = nil, directives: [Directive]? = nil) {
        self.name = name
        self.alias = alias
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)\(try self.serializedDirectives())"
    }
}

/// Represents a `Field` which is an object type in the schema.
public struct Object: Field, AcceptsArguments, AcceptsSelectionSet, AcceptsDirectives {
    public let name: String
    public let alias: String?
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let arguments: [String : InputValue]?
    public let directives: [Directive]?
    
    public init(name: String, alias: String? = nil, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, arguments: [String : InputValue]? = nil, directives: [Directive]? = nil) {
        self.name = name
        self.alias = alias
        self.fields = fields
        self.fragments = fragments
        self.arguments = arguments
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)\(try self.serializedArguments())\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}

/// Defines a _Directive_ from the GraphQL language.
public struct Directive: AcceptsArguments, QueryConvertible {
    public let name: String
    public let arguments: [String : InputValue]?
    
    public init(name: String, arguments: [String : InputValue]? = nil) {
        self.name = name
        self.arguments = arguments
    }
    
    /// @ Name Arguments opt
    public func graphQLString() throws -> String {
        return "@\(self.name)\(try self.serializedArguments())"
    }
}

public protocol AcceptsDirectives {
    var directives: [Directive]? { get }
    func serializedDirectives() throws -> String
}

public extension AcceptsDirectives {
    func serializedDirectives() throws -> String {
        guard let directives = self.directives else {
            return ""
        }
        
        return " " + (try directives.map { try $0.graphQLString() }.joined(separator: " "))
    }
}

/// Represents a GraphQL query sent by a request to the server.
public protocol GraphQLQuery: QueryConvertible { }

/// Represents a GraphQL variables payload sent by a request to the server.
public protocol GraphQLVariables {
    func graphQLVariablesDictionary() throws -> [AnyHashable : Any]
}

/// Defines an _OperationDefinition_ from the GraphQL language. Generally used as the `query` portion of a GraphQL request.
public struct Operation: GraphQLQuery, AcceptsSelectionSet, AcceptsVariableDefinitions, AcceptsDirectives {
    
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
    public let fragments: [FragmentSpread]?
    public let variableDefinitions: [AnyVariableDefinition]?
    public let directives: [Directive]?
    
    public init(type: OperationType, name: String, variableDefinitions: [AnyVariableDefinition]? = nil, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, directives: [Directive]? = nil) {
        self.type = type
        self.name = name
        self.fields = fields
        self.fragments = fragments
        self.variableDefinitions = variableDefinitions
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.type.graphQLString()) \(self.name)\(try self.serializedVariableDefinitions())\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}
