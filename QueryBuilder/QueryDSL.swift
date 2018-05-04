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
public protocol Field: FieldSerializable, AcceptsDirectives, QueryConvertible, SelectionType { }
public protocol ScalarField: Field { }
public extension ScalarField {
    var asSelection: Selection {
        return .scalar(name: self.name, alias: self.alias)
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
public struct InlineFragment: SelectionSetSerializable, InlineFragmentSerializable, SelectionType {
    public let typeName: String?
    public let directives: [Directive]?
    public let selectionSet: SelectionSet?
    public var selectionSetName: String { return self.asSelection.key }
    public var asSelection: Selection {
        return .inlineFragment(namedType: self.typeName, directives: self.directives, selectionSet: self.selectionSet!)
    }
    
    public init(typeName: String?, directives: [Directive]? = nil, selectionSet: SelectionSet) {
        self.typeName = typeName
        self.directives = directives
        self.selectionSet = selectionSet
    }
    
    public init(typeName: String?, directives: [Directive]? = nil, selectionSet: [SelectionType]) {
        self.init(typeName: typeName, directives: directives, selectionSet: SelectionSet(selectionSet))
    }
    
    public func serializedSelections() throws -> [String] {
        return try self.selectionSet?.selections.map { try $0.graphQLString() } ?? []
    }
    
    public func graphQLString() throws -> String {
        return try inlineFragmentGraphQLString(for: self, with: self.typeName)
    }
}

/// Defines a _FragmentSpread_ from the GraphQL language.
/// Accepted by any type which inherits `AcceptsSelectionSet`.
public struct FragmentSpread: AcceptsDirectives, QueryConvertible, SelectionType {
    public let name: String
    public let directives: [Directive]?
    
    public var asSelection: Selection {
        return .fragmentSpread(name: self.name, directives: self.directives)
    }
    
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
    public let directives: [Directive]?
    public let selectionSet: SelectionSet
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init?(name: String, type: String, directives: [Directive]? = nil, selectionSet: SelectionSet) {
        guard name != "on" else {
            return nil
        }
        guard selectionSet.selectionSet.count > 0 else {
            return nil
        }
        self.name = name
        self.type = type
        self.directives = directives
        self.selectionSet = selectionSet
    }
    
    public init?(name: String, type: String, directives: [Directive]? = nil, selectionSet: [SelectionType]) {
        self.init(name: name, type: type, directives: directives, selectionSet: SelectionSet(selectionSet))
    }
    
    public func graphQLString() throws -> String {
        return "fragment \(self.name) on \(self.type)\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}

public protocol SelectionSetSerializable {
    var selectionSetName: String { get }
    func serializedSelections() throws -> [String]
    func serializedSelectionSet() throws -> String
}

public extension SelectionSetSerializable {
    public func serializedSelectionSet() throws -> String {
        return try self.serializedSelectionSet(serializedSelections: try self.serializedSelections())
    }
    
    public func serializedSelectionSet(serializedSelections: [String]) throws -> String {
        let selectionSet = serializedSelections.flatMap { selection -> String? in
            guard selection.count > 0 else {
                return nil
            }
            return selection
        }.joined(separator: "\n")
        
        guard selectionSet.count > 0 else {
            throw QueryBuilderError.missingFields(selectionSetName: self.selectionSetName)
        }
        
        return " {\n\(selectionSet)\n}"
    }
}

/// Any type that accepts a _SelectionSet_ from the GraphQL Language.
public protocol AcceptsSelectionSet: SelectionSetSerializable {
    var selectionSet: SelectionSet { get }
}

public extension AcceptsSelectionSet {
    public func serializedSelections() throws -> [String] {
        return try self.selectionSet.selections.map { try $0.graphQLString() }
    }
}

/// Represents a _SelectionSet_ from the GraphQL Language. Preserves order of selection insertion and array initialization.
public struct SelectionSet: ExpressibleByArrayLiteral, SelectionSetSerializable, QueryConvertible {
    private(set) var selectionSet = OrderedDictionary<String, Selection>()
    public var selections: [Selection] {
        return self.selectionSet.map { $0.value }
    }
    
    public var selectionSetName: String {
        return self.selectionSet.map { $0.key }.joined(separator: ", ")
    }
    
    public init(selectionSet: [String : Selection]) {
        self.selectionSet = OrderedDictionary(selectionSet)
    }
    
    public init(_ selection: SelectionType) {
        self.init([selection])
    }
    
    public init(_ selections: [SelectionType]) {
        var selectionSet = OrderedDictionary<String, Selection>()
        for element in selections {
            try! SelectionSet.insert(selection: element, into: &selectionSet)
        }
        self.selectionSet = selectionSet
    }
    
    public init(arrayLiteral elements: SelectionType...) {
        self.init(elements)
    }
    
    public mutating func insert(_ other: SelectionType) throws {
        try SelectionSet.insert(selection: other, into: &self.selectionSet)
    }
    
    public mutating func insert(contentsOf contents: SelectionSet) throws {
        try self.selectionSet.insert(contentsOf: contents.selectionSet)
    }
    
    static func insert(selection: SelectionType, into selectionSet: inout OrderedDictionary<String, Selection>) throws {
        let concreteSelection = selection.asSelection
        let key = concreteSelection.key
        if let existing = selectionSet.removeValue(forKey: key) {
            let merged = try existing.merge(selection: concreteSelection)
            selectionSet[key] = merged.selectionSet[key]
        }
        else {
            selectionSet[key] = concreteSelection
        }
    }
    
    public func serializedSelections() throws -> [String] {
        return try self.selections.map { try $0.graphQLString() }
    }
    
    public func graphQLString() throws -> String {
        return try self.serializedSelectionSet()
    }
}


public enum SelectionKind: String {
    case scalar
    case object
    case fragmentSpread
    case inlineFragment
}

/// Inherit to represent a _Selection_ from the GraphQL Language.
public protocol SelectionType {
    var asSelection: Selection { get }
}

/// Concretely represents a _Selection_ from the GraphQL Language.
public enum Selection: ObjectSerializable, InlineFragmentSerializable, SelectionType {
    case scalar(name: String, alias: String?)
    case object(name: String, alias: String?, arguments: [String : InputValue]?, directives: [Directive]?, selectionSet: SelectionSet)
    case fragmentSpread(name: String, directives: [Directive]?)
    case inlineFragment(namedType: String?, directives: [Directive]?, selectionSet: SelectionSet)
    
    // MARK: - Protocol conformances
    
    public var asSelection: Selection {
        return self
    }
    
    public var selectionSetName: String {
        return self.key
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
    
    public var kind: SelectionKind {
        switch self {
        case .scalar(_): return .scalar
        case .object(_): return .object
        case .fragmentSpread(_): return .fragmentSpread
        case .inlineFragment(_): return .inlineFragment
        }
    }
    
    public func serializedSelections() throws -> [String] {
        switch self {
        case .scalar(_):
            return []
        case .object(name: _, alias: _, arguments: _, directives: _, selectionSet: let selectionSet):
            return try selectionSet.serializedSelections()
        case .fragmentSpread(_):
            return []
        case .inlineFragment(namedType: _, directives: _, selectionSet: let selectionSet):
            return try selectionSet.serializedSelections()
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
            let selections = [self, selection]
            return SelectionSet(selections)
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
    
    public static func inputType() throws -> InputType {
        return .scalar(.id)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.value.jsonEncodedString()
    }
}

/// Conformance to this type will allow it to automatically be used as an _EnumValue_ for Input.
public protocol EnumValueProtocol: InputValue {
    /// The enum case in GraphQL. E.g. for a set of colors could be RED, GREEN, BLUE.
    func graphQLInputValue() throws -> String
}

public extension EnumValueProtocol {
    public static func inputType() throws -> InputType {
        return .enumValue(typeName: "\(Self.self)")
    }
}

/// `InputValue` representing an _EnumValue_.
public struct EnumValue<T>: InputValue {
    let caseName: String
    
    public init(caseName: String) throws {
        guard caseName != "null" && caseName != "true" && caseName != "false" else {
            throw QueryBuilderError.incorrectInputType(message: "An EnumValue can not have values named `null`, `true`, or `false`.")
        }
        self.caseName = caseName
    }
    
    public static func inputType() throws -> InputType {
        return .enumValue(typeName: "\(T.self)")
    }
    
    public func graphQLInputValue() throws -> String {
        return self.caseName
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

public struct AnyVariableDefinition: VariableDefinitionType {
    public let name: String
    public let typeName: InputType
    public let defaultValue: InputValue?
    
    public init<_InputValue>(variableDefinition: VariableDefinition<_InputValue>) throws {
        try self.init(name: variableDefinition.name, typeName: try _InputValue.inputType(), defaultValue: variableDefinition.defaultValue)
    }
    
    public init(name: String, typeName: InputType, defaultValue: InputValue? = nil) throws {
        if defaultValue is VariableDefinitionType {
            throw QueryBuilderError.incorrectInputType(message: "A VariableDefinition cannot use a default value of another VariableDefinition")
        }
        
        self.name = name
        self.typeName = typeName
        self.defaultValue = defaultValue
    }
}

public struct Variable: InputValue {
    public let name: String
    public init(name: String) {
        self.name = name
    }
    
    public static func inputType() throws -> InputType {
        throw QueryBuilderError.incorrectInputType(message: "`Variable` does not have a defined `InputType` and may only be used as an arbitrary variable for an `Argument` value. If you are attempting to construct a variable definition for an operation use `VariableDefinition` instead.")
    }
    
    public func graphQLInputValue() throws -> String {
        return "$" + self.name
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
public struct Scalar: ScalarField {
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
    public let directives: [Directive]?
    public let selectionSet: SelectionSet
    
    public var asSelection: Selection {
        return .object(name: self.name, alias: self.alias, arguments: self.arguments, directives: self.directives, selectionSet: self.selectionSet)
    }
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init(name: String, alias: String? = nil, arguments: [String : InputValue]? = nil, directives: [Directive]? = nil, selectionSet: SelectionSet) {
        self.name = name
        self.alias = alias
        self.arguments = arguments
        self.directives = directives
        self.selectionSet = selectionSet
    }
    
    public init(name: String, alias: String? = nil, arguments: [String : InputValue]? = nil, directives: [Directive]? = nil, selectionSet: [SelectionType]) {
        self.init(name: name, alias: alias, arguments: arguments, directives: directives, selectionSet: SelectionSet(selectionSet))
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
    public enum OperationType: String, QueryConvertible {
        case query
        case mutation
        case subscription
        
        public func graphQLString() throws -> String {
            return self.rawValue
        }
    }
    
    public let type: OperationType
    public let name: String
    public let variableDefinitions: [AnyVariableDefinition]?
    public let selectionSet: SelectionSet
    public let directives: [Directive]?
    
    public var selectionSetName: String {
        return self.name
    }
    
    public init(type: OperationType, name: String, variableDefinitions: [AnyVariableDefinition]? = nil, directives: [Directive]? = nil, selectionSet: SelectionSet) {
        self.type = type
        self.name = name
        self.variableDefinitions = variableDefinitions
        self.selectionSet = selectionSet
        self.directives = directives
    }
    
    public init(type: OperationType, name: String, variableDefinitions: [AnyVariableDefinition]? = nil, directives: [Directive]? = nil, selectionSet: [SelectionType]) {
        self.init(type: type, name: name, variableDefinitions: variableDefinitions, directives: directives, selectionSet: SelectionSet(selectionSet))
    }
    
    public func graphQLString() throws -> String {
        return "\(try self.type.graphQLString()) \(self.name)\(try self.serializedVariableDefinitions())\(try self.serializedDirectives())\(try self.serializedSelectionSet())"
    }
}

/// Defines an _Query Document_ from the GraphQL language.
/// This represents a full GraphQL request with Operations, Fragments, and VariableDefinitions.
/// Assigned Variables however are included separately in the request body.
public struct Document: GraphQLQuery {
    public let operations: [Operation]
    public let fragments: [FragmentDefinition]
    
    public init(operations: [Operation], fragments: [FragmentDefinition]) {
        self.operations = operations
        self.fragments = fragments
    }
    
    public func graphQLString() throws -> String {
        let operationQueries = try self.operations.map { try $0.graphQLString() }.joined(separator: "\n")
        let fragmentQueries = try self.fragments.map { try $0.graphQLString() }.joined(separator: "\n")
        return operationQueries + "\n" + fragmentQueries
    }
}
