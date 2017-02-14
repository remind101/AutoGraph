import Foundation

public enum JSONValue: CustomStringConvertible {
    case array([JSONValue])
    case object([String : JSONValue])
    case number(Double)
    case string(String)
    case bool(Bool)
    case null()
    
    public func values() -> AnyObject {
        switch self {
        case let .array(xs):
            return xs.map { $0.values() } as AnyObject
        case let .object(xs):
            return xs.mapValues { $0.values() } as AnyObject
        case let .number(n):
            return n as AnyObject
        case let .string(s):
            return s as AnyObject
        case let .bool(b):
            return b as AnyObject
        case .null():
            return NSNull()
        }
    }
    
    public func valuesAsNSObjects() -> NSObject {
        switch self {
        case let .array(xs):
            return xs.map { $0.values() } as NSObject
        case let .object(xs):
            return xs.mapValues { $0.values() } as NSObject
        case let .number(n):
            return NSNumber(value: n as Double)
        case let .string(s):
            return NSString(string: s)
        case let .bool(b):
            return NSNumber(value: b as Bool)
        case .null():
            return NSNull()
        }
    }
    
    public init<T>(array: Array<T>) throws {
        let jsonValues = try array.map {
            return try JSONValue(object: $0)
        }
        self = .array(jsonValues)
    }
    
    public init<V>(dict: Dictionary<String, V>) throws {
        var jsonValues = [String : JSONValue]()
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
        case let array as Array<Any>:
            let jsonValues = try array.map {
                return try JSONValue(object: $0)
            }
            self = .array(jsonValues)
            
        case let array as NSArray:
            let jsonValues = try array.map {
                return try JSONValue(object: $0)
            }
            self = .array(jsonValues)
            
        case let dict as Dictionary<String, Any>:
            var jsonValues = [String : JSONValue]()
            for (key, val) in dict {
                let x = try JSONValue(object: val)
                jsonValues[key] = x
            }
            self = .object(jsonValues)
            
        case let dict as NSDictionary:
            var jsonValues = [String : JSONValue]()
            for (key, val) in dict {
                let x = try JSONValue(object: val)
                jsonValues[key as! String] = x
            }
            self = .object(jsonValues)
        
        case let val as NSNumber:
            if val.isBool {
                self = .bool(val.boolValue)
            } else {
                self = .number(val.doubleValue)
            }
            
        case let val as NSString:
            self = .string(String(val))
            
        case is NSNull:
            self = .null()
            
        default:
            // TODO: Generate an enum of standard errors.
            let userInfo = [ NSLocalizedFailureReasonErrorKey : "\(type(of: (object))) cannot be converted to JSON" ]
            throw NSError(domain: "CRJSONErrorDomain", code: -1000, userInfo: userInfo)
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
            let userInfo = [ NSLocalizedFailureReasonErrorKey : "\(self) cannot be converted to JSON string" ]
            throw NSError(domain: "JSONValueErrorDomain", code: -1000, userInfo: userInfo)
        }
        
        if isWrapped {
            let start = string.index(string.startIndex, offsetBy: 1)
            let end = string.index(string.endIndex, offsetBy: -1)
            let range = start..<end
            string = string.substring(with: range)
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
    
    public subscript(index: JSONKeypath) -> JSONValue? {
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
            } else {
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
            guard let key = index.first else {
                return self
            }
            
            let keys = index.dropFirst()
            switch self {
            case .object(let obj):
                if let next = obj[key] {
                    return next[Array(keys)]
                } else {
                    return nil
                }
            case .array(let arr):
                return .array(arr.flatMap { $0[index] })
            default:
                return nil
            }
        }
        set (newValue) {
            guard let key = index.first else {
                return
            }
            
            if index.count == 1 {
                switch self {
                case .object(var obj):
                    if (newValue != nil) {
                        obj.updateValue(newValue!, forKey: key)
                    } else {
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
                    next[Array(keys)] = newValue
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
        case .null():
            return "JSONNull()"
        case let .bool(b):
            return "JSONBool(\(b))"
        case let .string(s):
            return "JSONString(\(s))"
        case let .number(n):
            return "JSONNumber(\(n))"
        case let .object(o):
            return "JSONObject(\(o))"
        case let .array(a):
            return "JSONArray(\(a))"
        }
    }
}

// MARK: - Protocols
// MARK: - Hashable, Equatable

extension JSONValue: Hashable {
    
    static let prime = 31
    static let truePrime = 1231;
    static let falsePrime = 1237;
    
    public var hashValue: Int {
        switch self {
        case .null():
            return JSONValue.prime
        case let .bool(b):
            return b ? JSONValue.truePrime: JSONValue.falsePrime
        case let .string(s):
            return s.hashValue
        case let .number(n):
            return n.hashValue
        case let .object(obj):
            return obj.reduce(1, { (accum: Int, pair: (key: String, val: JSONValue)) -> Int in
                return accum.hashValue ^ pair.key.hashValue ^ pair.val.hashValue.byteSwapped
            })
        case let .array(xs):
            return xs.reduce(3, { (accum: Int, val: JSONValue) -> Int in
                return (accum.hashValue &* JSONValue.prime) ^ val.hashValue
            })
        }
    }
}

public func ==(lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.null(), .null()):
        return true
    case let (.bool(l), .bool(r)) where l == r:
        return true
    case let (.string(l), .string(r)) where l == r:
        return true
    case let (.number(l), .number(r)) where l == r:
        return true
    case let (.object(l), .object(r))
        where l.elementsEqual(r, by: {
            (v1: (String, JSONValue), v2: (String, JSONValue)) in
            v1.0 == v2.0 && v1.1 == v2.1
        }):
        return true
    case let (.array(l), .array(r)) where l.elementsEqual(r, by: { $0 == $1 }):
        return true
    default:
        return false
    }
}

public func !=(lhs: JSONValue, rhs: JSONValue) -> Bool {
    return !(lhs == rhs)
}

// MARK: - JSONKeypath

public protocol JSONKeypath {
    var keyPath: String { get }
}

extension String: JSONKeypath {
    public var keyPath: String {
        return self
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.string(self).encodeAsString()
    }
}

extension Int: JSONKeypath {
    public var keyPath: String {
        return String(self)
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(Double(self)).encodeAsString()
    }
}

extension Double: JSONKeypath {
    public var keyPath: String {
        return String(self)
    }
    
    public func jsonEncodedString() throws -> String {
        return try JSONValue.number(self).encodeAsString()
    }
}
