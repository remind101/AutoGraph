import Foundation
import JSONValueRX

enum QueryBuilderError: LocalizedError {
    case incorrectArgumentKey(key: Any)
    case incorrectArgumentValue(value: Any)
    case incorrectInputType(message: String)
    case missingFields(selectionSetName: String)
    case selectionMergeFailure(selection1: Selection, selection2: Selection)
    
    public var errorDescription: String? {
        switch self {
        case .incorrectArgumentValue(let value):
            return "value \(value) is not an `InputValue`"
        case .incorrectArgumentKey(let key):
            return "key \(key) is not a `String`"
        case .incorrectInputType(message: let message):
            return message
        case .missingFields(selectionSetName: let selectionSetName):
            return "Selection Set on \(selectionSetName) must have either `fields` or `fragments` or both"
        case .selectionMergeFailure(selection1: let selection1, selection2: let selection2):
            return "Cannot merge selection \(selection1.key) of kind \(selection1.kind) with selection \(selection2.key) of kind \(selection2.kind)"
        }
    }
}

public struct OrderedDictionary<Key: Hashable, Value> {
    public var dictionary = [Key : Value]()
    public var keys = [Key]()
    public var values: [Value] {
        return self.keys.compactMap { dictionary[$0] }
    }
    
    public var count: Int {
        assert(keys.count == dictionary.count, "Keys and values array out of sync")
        return self.keys.count
    }
    
    public init() {}
    public init(_ dictionary: [Key : Value]) {
        for (key, value) in dictionary {
            self.keys.append(key)
            self.dictionary[key] = value
        }
    }
    
    public subscript(index: Int) -> Value? {
        get {
            let key = self.keys[index]
            return self.dictionary[key]
        }
        set(newValue) {
            let key = self.keys[index]
            if newValue != nil {
                self.dictionary[key] = newValue
            }
            else {
                self.dictionary.removeValue(forKey: key)
                self.keys.remove(at: index)
            }
        }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            return self.dictionary[key]
        }
        set(newValue) {
            if let newValue = newValue {
                if self.dictionary.updateValue(newValue, forKey: key) == nil {
                    self.keys.append(key)
                }
            }
            else {
                if self.dictionary.removeValue(forKey: key) != nil {
                    guard let index = self.keys.index(of: key) else {
                        fatalError("OrderedDictionary attempted to remove value for key \"\(key)\" that has no index.")
                    }
                    self.keys.remove(at: index)
                }
            }
        }
    }
    
    public mutating func insert(contentsOf contents: OrderedDictionary<Key, Value>) throws {
        for key in contents.keys {
            self[key] = contents.dictionary[key]
        }
    }
    
    public mutating func removeValue(forKey key: Key) -> Value? {
        let value = self[key]
        self[key] = nil
        return value
    }
    
    public func map<T>(_ transform: ((key: Key, value: Value)) throws -> T) rethrows -> [T] {
        var output = [T]()
        for key in keys {
            if let value = self.dictionary[key] {
                output.append(try transform((key, value)))
            }
        }
        return output
    }
    
    var description: String {
        var result = "{\n"
        for i in 0..<self.count {
            result += "[\(i)]: \(self.keys[i]) => \(String(describing: self[i]))\n"
        }
        result += "}"
        return result
    }
}

extension String: ScalarField, InputValue, GraphQLDocument {
    public static func inputType() throws -> InputType {
        return .scalar(.string)
    }

    public var alias: String? {
        return nil
    }
    
    public var directives: [Directive]? {
        return nil
    }

    public func graphQLString() throws -> String {
        return self.name
    }

    public var name: String {
        return self
    }

    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    // TODO: At somepoint we can "verifyNoWhitespace" and throw an error instead.
    var withoutWhitespace: String {
        return self.replace(" ", with: "")
    }
    
    private func replace(_ string: String, with replacement: String) -> String {
        return self.replacingOccurrences(of: string, with: replacement, options: NSString.CompareOptions.literal, range: nil)
    }
}

extension Int: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.int)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
}

extension UInt: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.int)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

extension Double: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.float)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
}

extension Bool: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.boolean)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.bool(self).encodeAsString()
    }
}

extension Float: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.float)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

extension NSNull: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.null)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.null.encodeAsString()
    }
}

extension NSNumber: InputValue {
    public static func inputType() throws -> InputType {
        return .scalar(.float)
    }
    
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(truncating: self)).encodeAsString()
    }
}

// This can be cleaned up once conditional conformances are added to the language https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md .
extension Array: InputValue {
    public static func inputType() throws -> InputType {
        guard case let elementType as InputValue.Type = Element.self else {
            throw QueryBuilderError.incorrectArgumentValue(value: Element.self)
        }
        
        return .list(try elementType.inputType())
    }
    
    public func graphQLInputValue() throws -> String {
        let values: [String] = try self.map {
            guard case let value as InputValue = $0 else {
                throw QueryBuilderError.incorrectArgumentValue(value: $0)
            }
            return try value.graphQLInputValue()
        }
        
        return "[" + values.joined(separator: ", ") + "]"
    }
}

extension Dictionary: InputValue {
    public static func inputType() throws -> InputType {
        throw QueryBuilderError.incorrectInputType(message: "Dictionary does not have a defined `InputType`, please use `InputObjectType` instead")
    }
    
    public func graphQLInputValue() throws -> String {
        let inputs: [String] = try self.map {
            guard case let key as String = $0 else {
                throw QueryBuilderError.incorrectArgumentKey(key: $0)
            }
            guard case let value as InputValue = $1 else {
                throw QueryBuilderError.incorrectArgumentValue(value: $1)
            }
            return key + ": " + (try value.graphQLInputValue())
        }
        
        return "{" + inputs.joined(separator: ", ") + "}"
    }
}

extension Dictionary: GraphQLVariables {
    public func graphQLVariablesDictionary() throws -> [AnyHashable : Any] {
        return self
    }
}
