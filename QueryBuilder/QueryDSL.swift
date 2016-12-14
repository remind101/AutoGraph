import Foundation

public protocol QueryConvertible {
    var graphQLString: String { get }
}

public protocol Field: QueryConvertible {
    var name: String { get }
    var alias: String? { get }
    var serializedAlias: String { get }
}

public extension Field {
    var serializedAlias: String {
        guard let alias = self.alias else {
            return ""
        }
        return "\(alias.withoutWhitespace): "
    }
}

public protocol AcceptsFields {
    var fields: [Field]? { get }
    var serializedFields: String { get }
}

public extension AcceptsFields {
    var serializedFields: String {
        guard let fields = self.fields else {
            return ""
        }
        
        let fieldsList = fields.map { $0.graphQLString }.joined(separator: "\n")
        return fieldsList
    }
}

// TODO: may want to make this a protocol so that we have concrete fragments b/c
// all fragments must have unique names.
public struct Fragment: AcceptsSelectionSet, QueryConvertible {
    public let name: String
    public let type: String
    public let fields: [Field]?
    public let fragments: [Fragment]?
    
    public init?(name: String, type: String, fields: [Field]?, fragments: [Fragment]?) {
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
    
    public var graphQLString: String {
        return "fragment \(self.name) on \(self.type)\(self.serializedSelectionSet)"
    }
}

public protocol AcceptsSelectionSet: AcceptsFields {
    var fields: [Field]? { get }
    var fragments: [Fragment]? { get }
    var serializedFragments: String { get }
    var serializedSelectionSet: String { get }
}

public extension AcceptsSelectionSet {
    var serializedSelectionSet: String {
        let fields = self.serializedFields
        let fragments = self.serializedFragments
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
    
    var serializedFragments: String {
        guard let fragments = self.fragments else {
            return ""
        }
        
        let fragmentsList = fragments.map { "...\($0.name)" }.joined(separator: "\n")
        return fragmentsList
    }
}

public protocol Argument {
    var graphQLArgument: String { get }
}

public protocol AcceptsArguments {
    var arguments: [(key: String, value: Argument)]? { get }
    var serializedArguments: String { get }
}

public extension AcceptsArguments {
    var serializedArguments: String {
        guard let arguments = self.arguments else {
            return ""
        }
        
        let argumentsList = arguments.map { (key, value) in
            "\(key): \(value.graphQLArgument)"
        }.joined(separator: ", ")
        
        return "(\(argumentsList))"
    }
}

public struct Scalar: Field {
    public let name: String
    public let alias: String?
    
    public init(name: String, alias: String?) {
        self.name = name
        self.alias = alias
    }
    
    public var graphQLString: String {
        return "\(self.serializedAlias)\(name)"
    }
}

public struct Object: Field, AcceptsArguments, AcceptsSelectionSet {
    public let name: String
    public let alias: String?
    public let fields: [Field]?
    public let fragments: [Fragment]?
    public let arguments: [(key: String, value:
    Argument)]?
    
    public init(name: String, alias: String?, fields: [Field]?, fragments: [Fragment]?, arguments: [(key: String, value:
        Argument)]?) {
        self.name = name
        self.alias = alias
        self.fields = fields
        self.fragments = fragments
        self.arguments = arguments
    }
    
    public var graphQLString: String {
        return "\(self.serializedAlias)\(name)\(self.serializedArguments)\(self.serializedSelectionSet)"
    }
}

public struct Operation: AcceptsSelectionSet, QueryConvertible, AcceptsArguments {
    public enum OperationType: QueryConvertible {
        case Query
        case Mutation
        
        public var graphQLString: String {
            switch self {
            case .Query:
                return "query"
            case .Mutation:
                return "mutation"
            }
        }
    }
    
    public let type: OperationType
    public let name: String
    public let fields: [Field]?
    public let fragments: [Fragment]?
    public let arguments: [(key: String, value: Argument)]?
    
    public init(type: OperationType, name: String, fields: [Field]?, fragments: [Fragment]?, arguments: [(key: String, value: Argument)]?) {
        self.type = type
        self.name = name
        self.fields = fields
        self.fragments = fragments
        self.arguments = arguments
    }
    
    public var graphQLString: String {
        return "\(self.type.graphQLString) \(self.name)\(self.serializedArguments)\(self.serializedSelectionSet)"
    }
}
