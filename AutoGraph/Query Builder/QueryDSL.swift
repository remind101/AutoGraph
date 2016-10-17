import Foundation

protocol QueryConvertible {
    var graphQLString: String { get }
}

protocol Field: QueryConvertible {
    var name: String { get }
    var alias: String? { get }
    var serializeAlias: String { get }
}

extension Field {
    var serializeAlias: String {
        guard let alias = self.alias else {
            return ""
        }
        return alias
    }
}

protocol AcceptsFields {
    var fields: [Field]? { get }
    var serializedFields: String { get }
}

extension AcceptsFields {
    var serializedFields: String {
        guard let fields = self.fields else {
            return ""
        }
        
        let fieldsList = fields.map { $0.graphQLString }.joined(separator: "\n")
        return fieldsList
    }
}

protocol Argument: QueryConvertible { }

protocol AcceptsArguments {
    var arguments: [(key: String, value: Argument)]? { get }
    var serializedArguments: String { get }
}

extension AcceptsArguments {
    var serializedArguments: String {
        guard let arguments = self.arguments else {
            return ""
        }
        
        let argumentsList = arguments.map { (key, value) in
            "\(key): \(value.graphQLString)"
            }.joined(separator: ", ")
        
        return "(\(argumentsList))"
    }
}

struct Scalar: Field {
    let name: String
    let alias: String?
    
    var graphQLString: String {
        return "\(self.serializeAlias): \(name)"
    }
}

struct Object: Field, AcceptsArguments, AcceptsFields {
    let name: String
    let alias: String?
    let fields: [Field]?
    let arguments: [(key: String, value: Argument)]?
    
    var graphQLString: String {
        return "\(self.serializeAlias): \(name)\(self.serializedArguments) {\n\(self.serializedFields)\n}"
    }
}

struct Operation: AcceptsFields, QueryConvertible {
    let name: String
    let fields: [Field]?
    let arguments: [(key: String, value: Argument)]
    
    var graphQLString: String {
        return "query \(self.name) {\n\(self.serializedFields)\n}"
    }
}
