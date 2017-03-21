import Foundation
import JSONValueRX

enum QueryBuilderError: LocalizedError {
    case incorrectArgumentKey(key: Any)
    case incorrectArgumentValue(value: Any)
    
    public var errorDescription: String? {
        switch self {
        case .incorrectArgumentValue(let value):
            return "value \(value) is not an `InputValue`"
        case .incorrectArgumentKey(let key):
            return "key \(key) is not a `String`"
        }
    }
}

extension String: Field, InputValue {
    public var alias: String? {
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
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
}

extension UInt: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

extension Double: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
}

extension Bool: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.bool(self).encodeAsString()
    }
}

extension Float: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

extension NSNull: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.null().encodeAsString()
    }
}

extension NSNumber: InputValue {
    public func graphQLInputValue() throws -> String {
        return try self.jsonEncodedString()
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

// This can be cleaned up once conditional conformances are added to the language https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md .
extension Array: InputValue {
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
