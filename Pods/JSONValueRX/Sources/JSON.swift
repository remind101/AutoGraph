import Foundation

enum JSONValueError: LocalizedError {
    case objectFailedToConvertToJSON(objectType: Any.Type)
    case encodeAsJSONStringFailed(object: AnyObject)
    
    var errorDescription: String? {
        switch self {
        case .objectFailedToConvertToJSON(let objectType):
            return "Object of type \(objectType) failed to convert to JSON"
        case .encodeAsJSONStringFailed(let object):
            return "\(object) failed to convert to JSON string"
        }
    }
}

public enum JSONNumber: CustomStringConvertible, Hashable {
    case int(Int64)
    case fraction(Double)
    
    public var asNSNumber: NSNumber {
        switch self {
        case .int(let i):       return NSNumber(value: i)
        case .fraction(let f):  return NSNumber(value: f)
        }
    }
    
    public var description: String {
        switch self {
        case .int(let i):       return "\(i)"
        case .fraction(let f):  return "\(f)"
        }
    }
}

public enum JSONValue: CustomStringConvertible, Hashable {
    case array([JSONValue])
    case object([String: JSONValue])
    case number(JSONNumber)
    case string(String)
    case bool(Bool)
    case null
    
    public func values() -> AnyObject {
        switch self {
        case .array(let xs):
            return xs.map { $0.values() } as AnyObject
        case .object(let xs):
            return xs.mapValues { $0.values() } as AnyObject
        case .number(let n):
            switch n {
            case .int(let i): return i as AnyObject
            case .fraction(let f): return f as AnyObject
            }
        case .string(let s):
            return s as AnyObject
        case .bool(let b):
            return b as AnyObject
        case .null:
            return NSNull()
        }
    }
    
    public func valuesAsNSObjects() -> NSObject {
        switch self {
        case .array(let xs):
            return xs.map { $0.values() } as NSObject
        case .object(let xs):
            return xs.mapValues { $0.values() } as NSObject
        case .number(let n):
            switch n {
            case .int(let i): return NSNumber(value: i)
            case .fraction(let f): return NSNumber(value: f)
            }
        case .string(let s):
            return NSString(string: s)
        case .bool(let b):
            return NSNumber(value: b as Bool)
        case .null:
            return NSNull()
        }
    }
    
    public init<T>(array: [T]) throws {
        let jsonValues = try array.map {
            try JSONValue(object: $0)
        }
        self = .array(jsonValues)
    }
    
    public init<V>(dict: [String: V]) throws {
        var jsonValues = [String: JSONValue]()
        for (key, val) in dict {
            let x = try JSONValue(object: val)
            jsonValues[key] = x
        }
        self = .object(jsonValues)
    }
    
    // NOTE: Would be nice to figure out a generic recursive way of solving this.
    // Array<Dictionary<String, Any>> doesn't seem to work. Maybe case eval on generic param too?
    public init(object: Any) throws {
        switch object {
        case let array as [Any]:
            let jsonValues = try array.map {
                try JSONValue(object: $0)
            }
            self = .array(jsonValues)
            
        case let array as NSArray:
            let jsonValues = try array.map {
                try JSONValue(object: $0)
            }
            self = .array(jsonValues)
            
        case let dict as [String: Any]:
            var jsonValues = [String: JSONValue]()
            for (key, val) in dict {
                let x = try JSONValue(object: val)
                jsonValues[key] = x
            }
            self = .object(jsonValues)
            
        case let dict as NSDictionary:
            var jsonValues = [String: JSONValue]()
            for (key, val) in dict {
                let x = try JSONValue(object: val)
                jsonValues[key as! String] = x
            }
            self = .object(jsonValues)
            
        case let val as NSNumber:
            if val.isBool {
                self = .bool(val.boolValue)
            }
            else if val.isReal {
                self = .number(.fraction(val.doubleValue))
            }
            else {
                self = .number(.int(val.int64Value))
            }
            
        case let val as NSString:
            self = .string(String(val))
            
        case is NSNull:
            self = .null
            
        default:
            throw JSONValueError.objectFailedToConvertToJSON(objectType: type(of: object))
        }
    }
    
    public func encode() throws -> Data {
        return try JSONSerialization.data(withJSONObject: self.values(), options: JSONSerialization.WritingOptions(rawValue: 0))
    }
    
    public func encodeAsString(_ prettyPrinted: Bool = false) throws -> String {
        let options = prettyPrinted ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization.WritingOptions(rawValue: 0)
        let (object, isWrapped): (AnyObject, Bool) = {
            let values = self.values()
            guard JSONSerialization.isValidJSONObject(values) else {
                return ([values] as AnyObject, true)
            }
            return (values, false)
        }()
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        guard var string = String(data: data, encoding: .utf8) else {
            throw JSONValueError.encodeAsJSONStringFailed(object: object)
        }
        
        if isWrapped {
            let start = string.index(string.startIndex, offsetBy: 1)
            let end = string.index(string.endIndex, offsetBy: -1)
            let range = start ..< end
            string = String(string[range])
        }
        
        return string
    }
    
    public static func decode(_ data: Data) throws -> JSONValue {
        let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
        return try JSONValue(object: json)
    }
    
    public static func decode(_ string: String) throws -> JSONValue {
        return try JSONValue.decode(string.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
    }
    
    public subscript(index: JSONKeyPath) -> JSONValue? {
        get {
            switch self {
            case .object(_):
                return self[index.keyPath]
            case .array(let arr):
                switch index {
                case let i as Int:
                    guard i < arr.count else {
                        return nil
                    }
                    return arr[i]
                default:
                    return self[index.keyPath]
                }
            case .null:
                return .null
            default:
                return nil
            }
        }
        set(newValue) {
            switch self {
            case .object(_):
                self[index.keyPath] = newValue
            case .array(var arr):
                switch index {
                case let i as Int:
                    if let newValue = newValue {
                        arr.insert(newValue, at: i)
                    }
                    else {
                        arr.remove(at: i)
                    }
                    self = .array(arr)
                default:
                    self[index.keyPath] = newValue
                }
            default:
                return
            }
        }
    }
    
    subscript(index: String) -> JSONValue? {
        get {
            let components = index.components(separatedBy: ".")
            if let result = self[components] {
                return result
            }
            else {
                return self[[index]]
            }
        }
        set(newValue) {
            let components = index.components(separatedBy: ".")
            self[components] = newValue
        }
    }
    
    public subscript(index: [String]) -> JSONValue? {
        get {
            let sliceIndex = ArraySlice(index)
            return self[sliceIndex]
        }
        set {
            let sliceIndex = ArraySlice(index)
            self[sliceIndex] = newValue
        }
    }
    
    public subscript(index: ArraySlice<String>) -> JSONValue? {
        get {
            guard let key = index.first else {
                return self
            }
            
            let keys = index.dropFirst()
            switch self {
            case .object(let obj):
                if let next = obj[key] {
                    return next[keys]
                }
                else {
                    return nil
                }
            case .array(let arr):
                return .array(arr.compactMap { $0[index] })
            case .null:
                return .null
            default:
                return nil
            }
        }
        set(newValue) {
            guard let key = index.first else {
                return
            }
            
            if index.count == 1 {
                switch self {
                case .object(var obj):
                    if newValue != nil {
                        obj.updateValue(newValue!, forKey: key)
                    }
                    else {
                        obj.removeValue(forKey: key)
                    }
                    self = .object(obj)
                default:
                    return
                }
            }
            
            let keys = index.dropFirst()
            switch self {
            case .object(var obj):
                if var next = obj[key] {
                    next[keys] = newValue
                    obj.updateValue(next, forKey: key)
                    self = .object(obj)
                }
            default:
                return
            }
        }
    }
    
    public var description: String {
        switch self {
        case .null:
            return "null"
        case .bool(let b):
            return "\(b)"
        case .string(let s):
            return "\(s)"
        case .number(let n):
            return "\(n)"
        case .object(let o):
            return "JSON(\(o))"
        case .array(let a):
            return "JSON(\(a))"
        }
    }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        else if let value = try? container.decode(Int64.self) {
            self = .number(.int(value))
        }
        else if let value = try? container.decode(Double.self) {
            self = .number(.fraction(value))
        }
        else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        }
        else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        }
        else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        }
        else if container.decodeNil() {
            self = .null
        }
        else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Decoded value is not JSON"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        case .number(let number):
            switch number {
            case .int(let integer): try container.encode(integer)
            case .fraction(let fraction): try container.encode(fraction)
            }
        case .string(let string): try container.encode(string)
        case .bool(let bool): try container.encode(bool)
        case .null: try container.encodeNil()
        }
    }
    
    public func decode<T: Decodable>() throws -> T {
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: encoded)
    }
}

// MARK: - Protocols

// MARK: - JSONKeyPath

public protocol JSONKeyPath {
    var keyPath: String { get }
}

extension String: JSONKeyPath {
    public var keyPath: String {
        return self
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.string(self).encodeAsString()
    }
}

extension Int: JSONKeyPath {
    public var keyPath: String {
        return String(self)
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(.int(Int64(self))).encodeAsString()
    }
}

extension Int64: JSONKeyPath {
    public var keyPath: String {
        return String(self)
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(.int(self)).encodeAsString()
    }
}

extension Double {
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(.fraction(self)).encodeAsString()
    }
}
