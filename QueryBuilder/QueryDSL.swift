import Foundation
import JSONValueRX

public protocol QueryConvertible {
    func graphQLString() throws -> String
}

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

public protocol AcceptsFields {
    var fields: [Field]? { get }
    func serializedFields() throws -> String
}

// TODO: all serialization should be throwable. construction should not.
public extension AcceptsFields {
    func serializedFields() throws -> String {
        guard let fields = self.fields else {
            return ""
        }
        
        let fieldsList = try fields.map { try $0.graphQLString() }.joined(separator: "\n")
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
    
    public func graphQLString() throws -> String {
        return "fragment \(self.name) on \(self.type)\(try self.serializedSelectionSet())"
    }
}

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

public protocol Argument {
    func graphQLArgument() throws -> String
}

public protocol AcceptsArguments {
    var arguments: [(key: String, value: Argument)]? { get }
    func serializedArguments() throws -> String
}

public extension AcceptsArguments {
    func serializedArguments() throws -> String {
        
        guard let arguments = self.arguments else {
            return ""
        }
        
        let argumentsList = try arguments.map { (key, value) in
            "\(key): \(try value.graphQLArgument())"
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
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)"
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
    
    public func graphQLString() throws -> String {
        return "\(try self.serializedAlias())\(name)\(try self.serializedArguments())\(try self.serializedSelectionSet())"
    }
}

public struct Operation: AcceptsSelectionSet, QueryConvertible, AcceptsArguments {
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
    public let arguments: [(key: String, value: Argument)]?
    
    public init(type: OperationType, name: String, fields: [Field]?, fragments: [Fragment]?, arguments: [(key: String, value: Argument)]?) {
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
