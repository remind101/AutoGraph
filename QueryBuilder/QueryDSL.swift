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

public protocol AcceptsSelectionSet: AcceptsFields {
    var serializedSelectionSet: String { get }
}

public extension AcceptsSelectionSet {
    var serializedSelectionSet: String {
        let fields = self.serializedFields
        guard fields.characters.count > 0 else {
            return ""
        }
        return " {\n\(fields)\n}"
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
    
    public var graphQLString: String {
        return "\(self.serializedAlias)\(name)"
    }
}

public struct Object: Field, AcceptsArguments, AcceptsSelectionSet {
    public let name: String
    public let alias: String?
    public let fields: [Field]?
    public let arguments: [(key: String, value:
    Argument)]?
    
    public var graphQLString: String {
        return "\(self.serializedAlias)\(name)\(self.serializedArguments)\(self.serializedSelectionSet)"
    }
}

public struct Operation: AcceptsSelectionSet, QueryConvertible {
    let name: String
    public let fields: [Field]?
    let arguments: [(key: String, value: Argument)]
    
    public var graphQLString: String {
        return "query \(self.name)\(self.serializedSelectionSet)"
    }
}
