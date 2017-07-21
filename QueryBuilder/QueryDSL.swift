import Foundation
import JSONValueRX

/// Defines a type which can be converted to a GraphQL string. This includes queries and fragments.
public protocol QueryConvertible {
    func graphQLString() throws -> String
}

public protocol FieldSerializable {
    var name: String { get }
    var alias: String? { get }
    func serializedAlias() throws -> String
}

public extension FieldSerializable {
    func serializedAlias() throws -> String {
        guard let alias = self.alias else {
            return ""
        }
        return "\(alias.withoutWhitespace): "
    }
}

/// Defines a _Field_ from the GraphQL language. Inherited by `Object` and `Scalar`.
public protocol Field: FieldSerializable, AcceptsDirectives, QueryConvertible { }

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

public protocol InlineFragmentSerializable: SelectionSetSerializable, AcceptsDirectives, QueryConvertible { }

public func inlineFragmentGraphQLString(for inlineFragment: InlineFragmentSerializable, with typeName: String?) throws -> String {
    let typeCondition: String = {
        guard let typeName = typeName else {
            return ""
        }
        return "on \(typeName)"
    }()
    return "... \(typeCondition)\(try inlineFragment.serializedDirectives())\(try inlineFragment.serializedSelectionSet())"
}

/// Defines an _InlineFragment_ from the GraphQL language.
public struct InlineFragment: AcceptsSelectionSet, InlineFragmentSerializable {
    public let typeName: String?
    public let directives: [Directive]?
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let inlineFragments: [InlineFragment]?
    public var selectionSetName: String { return self.typeName ?? "..." }
    
    public init(typeName: String?, directives: [Directive]? = nil, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, inlineFragments: [InlineFragment]? = nil) {
        self.typeName = typeName
        self.directives = directives
        self.fields = fields
        self.fragments = fragments
        self.inlineFragments = inlineFragments
    }
    
    public func graphQLString() throws -> String {
        return try inlineFragmentGraphQLString(for: self, with: self.typeName)
    }
}

/// Defines a _FragmentSpread_ from the GraphQL language.
/// Accepted by any type which inherits `AcceptsSelectionSet`.
public struct FragmentSpread: AcceptsDirectives, QueryConvertible {
    public let name: String
    public let directives: [Directive]?
    
    public init(fragment: FragmentDefinition, directives: [Directive]? = nil) {
        self.init(name: fragment.name, directives: directives)
    }
    
    public init(name: String, directives: [Directive]? = nil) {
        self.name = name
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "...\(self.name)\(try self.serializedDirectives())"
    }
}

/// Defines a _FragmentDefinition_ from the GraphQL language.
public struct FragmentDefinition: AcceptsSelectionSet, AcceptsDirectives, QueryConvertible {
    public let name: String
    public let type: String
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let inlineFragments: [InlineFragment]?
    public let directives: [Directive]?
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init?(name: String, type: String, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, inlineFragments: [InlineFragment]? = nil, directives: [Directive]? = nil) {
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
        self.inlineFragments = inlineFragments
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "fragment \(self.name) on \(self.type)\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}

public protocol SelectionSetSerializable {
    var selectionSetName: String { get }
    func serializedSelectionSet() throws -> String
    func serializedSelectionSetComponents() throws -> (fields: String?, fragmentSpreads: String?, inlineFragments: String?)
}

public extension SelectionSetSerializable {
    public func serializedSelectionSet() throws -> String {
        let (fields, fragments, inlineFragments) = try self.serializedSelectionSetComponents()
        return try self.serializedSelectionSet(serializedFields: fields ?? "",
                                               serializedFragments: fragments ?? "",
                                               serializedInlineFragments: inlineFragments ?? "")
    }
    
    public func serializedSelectionSet(serializedFields: String, serializedFragments: String, serializedInlineFragments: String) throws -> String {
        let selectionSet = [serializedFields, serializedFragments, serializedInlineFragments].flatMap { selection -> String? in
            guard selection.characters.count > 0 else {
                return nil
            }
            return selection
        }.joined(separator: "\n")
        
        guard selectionSet.characters.count > 0 else {
            throw QueryBuilderError.missingFields(selectionSetName: self.selectionSetName)
        }
        
        return " {\n\(selectionSet)\n}"
    }
}

/// Any type that accepts a _SelectionSet_ from the GraphQL Language.
///
/// This type must accept `Field`s and `Fragment`s and must include either a set of
/// `fragments` _(FragmentSpread)_ or a set of `fields` or both.
public protocol AcceptsSelectionSet: AcceptsFields, SelectionSetSerializable {
    var fields: [Field]? { get }
    var fragments: [FragmentSpread]? { get }
    var inlineFragments: [InlineFragment]? { get }
    func serializedFragments() throws -> String
    func serializedSelectionSet() throws -> String
}

public extension AcceptsSelectionSet {
    public func serializedSelectionSetComponents() throws -> (fields: String?, fragmentSpreads: String?, inlineFragments: String?) {
        let fields = try self.serializedFields()
        let fragments = try self.serializedFragments()
        let inlineFragments = try self.serializedInlineFragments()
        return (fields, fragments, inlineFragments)
    }
    
    public func serializedInlineFragments() throws -> String {
        guard let inlineFragments = self.inlineFragments else {
            return ""
        }
        
        return try inlineFragments.map { try $0.graphQLString() }.joined(separator: "\n")
    }
    
    public func serializedFragments() throws -> String {
        guard let fragments = self.fragments else {
            return ""
        }
        
        let fragmentsList = try fragments.map { try $0.graphQLString() }.joined(separator: "\n")
        return fragmentsList
    }
}

/// Represents a _SelectionSet_ from the GraphQL Language.
public struct SelectionSet: ExpressibleByArrayLiteral {
    private(set) var selectionSet = [String : Selection]()
    public var selections: [Selection] {
        return self.selectionSet.map { $0.value }
    }
    
    public init(selectionSet: [String : Selection]) {
        self.selectionSet = selectionSet
    }
    
    public init(_ selection: Selection) {
        self.init([selection])
    }
    
    public init(_ selections: [Selection]) {
        var selectionSet = [String : Selection]()
        for element in selections {
            try! SelectionSet.insert(selection: element, into: &selectionSet)
        }
        self.selectionSet = selectionSet
    }
    
    public init(arrayLiteral elements: Selection...) {
        self.init(elements)
    }
    
    public mutating func insert(_ other: Selection) throws {
        try SelectionSet.insert(selection: other, into: &self.selectionSet)
    }
    
    public mutating func insert(contentsOf contents: SelectionSet) throws {
        for (_, selection) in contents.selectionSet {
            try self.insert(selection)
        }
    }
    
    static func insert(selection: Selection, into selectionSet: inout [String : Selection]) throws {
        let key = selection.key
        if let existing = selectionSet.removeValue(forKey: key) {
            let merged = try existing.merge(selection: selection)
            selectionSet[key] = merged.selectionSet[key]
        }
        else {
            selectionSet[key] = selection
        }
    }
}

/// Represents a _Selection_ from the GraphQL Language.
public enum Selection: ObjectSerializable, InlineFragmentSerializable {
    case scalar(name: String, alias: String?)
    case object(name: String, alias: String?, arguments: [String : InputValue]?, directives: [Directive]?, selectionSet: SelectionSet)
    case fragmentSpread(name: String, directives: [Directive]?)
    case inlineFragment(namedType: String?, directives: [Directive]?, selectionSet: SelectionSet)
    
    // MARK: - Protocol conformances
    
    public var selectionSetName: String {
        return self.name
    }
    
    public var name: String {
        switch self {
        case .scalar(name: let name, alias: _): return name
        case .object(name: let name, alias: _, arguments: _, directives: _, selectionSet: _): return name
        case .fragmentSpread(name: let name, directives: _): return name
        case .inlineFragment(namedType: let namedType, directives: _, selectionSet: _): return namedType ?? ""
        }
    }
    
    public var alias: String? {
        switch self {
        case .scalar(name: _, alias: let alias): return alias
        case .object(name: _, alias: let alias, arguments: _, directives: _, selectionSet: _): return alias
        case .fragmentSpread(_): return nil
        case .inlineFragment(_): return nil
        }
    }
    
    public var arguments: [String : InputValue]? {
        switch self {
        case .scalar(_): return nil
        case .object(name: _, alias: _, arguments: let args, directives: _, selectionSet: _): return args
        case .fragmentSpread(_): return nil
        case .inlineFragment(_): return nil
        }
    }
    
    public var directives: [Directive]? {
        switch self {
        case .scalar(_): return nil
        case .object(name: _, alias: _, arguments: _, directives: let dirs, selectionSet: _): return dirs
        case .fragmentSpread(name: _, directives: let dirs): return dirs
        case .inlineFragment(namedType: _, directives: let dirs, selectionSet: _): return dirs
        }
    }
    
    // MARK: - Utility
    
    public var key: String {
        switch self {
        case .scalar(let name, let alias): return alias != nil ? "\(alias!): \(name)" : name
        case .object(let name, let alias, _, _, _): return alias != nil ? "\(alias!): \(name)" : name
        case .fragmentSpread(let name, _): return name
        case .inlineFragment(let type, _, _): return "... on " + (type ?? "")
        }
    }
    
    public var kind: String {
        switch self {
        case .scalar(_): return "scalar"
        case .object(_): return "object"
        case .fragmentSpread(_): return "fragmentSpread"
        case .inlineFragment(_): return "inlineFragment"
        }
    }
    
    public func serializedSelectionSetComponents() throws -> (fields: String?, fragmentSpreads: String?, inlineFragments: String?) {
        switch self {
        case .scalar(_): return (try self.graphQLString(), nil, nil)
        case .object(_): return (try self.graphQLString(), nil, nil)
        case .fragmentSpread(_): return (nil, try self.graphQLString(), nil)
        case .inlineFragment(_): return (nil, nil, try self.graphQLString())
        }
    }
    
    public func graphQLString() throws -> String {
        switch self {
        case .scalar(name: let name, alias: let alias):
            return try Scalar(name: name, alias: alias).graphQLString()
        case .object(_):
            return try objectGraphQLString(for: self)
        case .fragmentSpread(name: let name, directives: let directives):
            return try FragmentSpread(name: name, directives: directives).graphQLString()
        case .inlineFragment(namedType: let namedType, directives: _, selectionSet: _):
            return try inlineFragmentGraphQLString(for: self, with: namedType)
        }
    }
    
    public func merge(selection: Selection) throws -> SelectionSet {
        let lkey = self.key
        let rkey = selection.key
        
        guard lkey == rkey else {
            let selections = [lkey : self, rkey : selection]
            return SelectionSet(selectionSet: selections)
        }
        
        // TODO: need better handling of differing arguments or directives.
        switch (self, selection) {
        case (.object(let lname, let lalias, let largs, let ldirs, var lfields), .object(_, _, _, _, let rfields)):
            try lfields.insert(contentsOf: rfields)
            let mergedObject: Selection = .object(name: lname, alias: lalias, arguments: largs, directives: ldirs, selectionSet: lfields)
            return SelectionSet(mergedObject)
            
        case (.scalar(_), .scalar(_)):
            return SelectionSet(self)
            
        case (.fragmentSpread(_), .fragmentSpread(_)):
            return SelectionSet(self)
            
        case (.inlineFragment(let lname, let ldirs, var lfields), .inlineFragment(_, _, let rfields)):
            try lfields.insert(contentsOf: rfields)
            let mergedFragment: Selection = .inlineFragment(namedType: lname, directives: ldirs, selectionSet: lfields)
            return SelectionSet(mergedFragment)
            
        default:
            throw QueryBuilderError.selectionMergeFailure(selection1: self, selection2: selection)
        }
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

public typealias ObjectSerializable = FieldSerializable & SelectionSetSerializable & AcceptsArguments & AcceptsDirectives & QueryConvertible

public func objectGraphQLString(for object: ObjectSerializable) throws -> String {
    return "\(try object.serializedAlias())\(object.name)\(try object.serializedArguments())\(try object.serializedDirectives())\(try object.serializedSelectionSet())"
}

/// Represents a `Field` which is an object type in the schema.
public struct Object: Field, AcceptsSelectionSet, ObjectSerializable {
    public let name: String
    public let alias: String?
    public let arguments: [String : InputValue]?
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let inlineFragments: [InlineFragment]?
    public let directives: [Directive]?
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init(name: String, alias: String? = nil, arguments: [String : InputValue]? = nil, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, inlineFragments: [InlineFragment]? = nil, directives: [Directive]? = nil) {
        self.name = name
        self.alias = alias
        self.arguments = arguments
        self.fields = fields
        self.fragments = fragments
        self.inlineFragments = inlineFragments
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return try objectGraphQLString(for: self)
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
        return try self.directives.serializedDirectives()
    }
}

public extension Optional where Wrapped == Array<Directive> {
    func serializedDirectives() throws -> String {
        guard let directives = self else {
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
    public let variableDefinitions: [AnyVariableDefinition]?
    public let fields: [Field]?
    public let fragments: [FragmentSpread]?
    public let inlineFragments: [InlineFragment]?
    public let directives: [Directive]?
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init(type: OperationType, name: String, variableDefinitions: [AnyVariableDefinition]? = nil, fields: [Field]? = nil, fragments: [FragmentSpread]? = nil, inlineFragments: [InlineFragment]? = nil, directives: [Directive]? = nil) {
        self.type = type
        self.name = name
        self.variableDefinitions = variableDefinitions
        self.fields = fields
        self.fragments = fragments
        self.inlineFragments = inlineFragments
        self.directives = directives
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.type.graphQLString()) \(self.name)\(try self.serializedVariableDefinitions())\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}
