import Foundation

// MARK: - JSONable

public protocol JSONDecodable {
    associatedtype ConversionType = Self
    static func fromJSON(_ json: JSONValue) -> ConversionType?
}

public protocol JSONEncodable {
    associatedtype ConversionType
    static func toJSON(_ val: ConversionType) -> JSONValue
}

public protocol JSONable: JSONDecodable, JSONEncodable { }

extension Dictionary: JSONable {
    public typealias ConversionType = Dictionary<String, Value>
    public static func fromJSON(_ json: JSONValue) -> Dictionary.ConversionType? {
        switch json {
        case .object:
            return json.values() as? Dictionary<String, Value>
        default:
            return nil
        }
    }
    
    public static func toJSON(_ dict: Dictionary.ConversionType) -> JSONValue {
        do {
            return try JSONValue(dict: dict)
        } catch {
            return JSONValue.null
        }
    }
}

extension Array: JSONable {
    public static func fromJSON(_ json: JSONValue) -> Array? {
        return json.values() as? Array
    }
    
    public static func toJSON(_ arr: Array) -> JSONValue {
        do {
            return try JSONValue(array: arr)
        } catch {
            return JSONValue.null
        }
    }
}

extension Bool: JSONable {
    public static func fromJSON(_ json: JSONValue) -> Bool? {
        switch json {
        case let .bool(b):
            return b
        case .number(.int(0)):
            return false
        case .number(.int(1)):
            return true
        default:
            return nil
        }
    }
    
    public static func toJSON(_ b: Bool) -> JSONValue {
        return JSONValue.bool(b)
    }
}

extension Int: JSONable {
    public static func fromJSON(_ json: JSONValue) -> Int? {
        switch json {
        case let .number(n):
            switch n {
            case .int(let i): return Int(exactly: i)
            case .fraction(let f): return Int(exactly: f)
            }
        case let .string(s):
            return Int(s)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ val: Int) -> JSONValue {
        return JSONValue.number(.int(Int64(val)))
    }
}

extension Double: JSONable {
    public static func fromJSON(_ json: JSONValue) -> Double? {
        switch json {
        case let .number(n):
            switch n {
            case .int(let i): return Double(i)
            case .fraction(let f): return f
            }
        case let .string(s):
            return Double(s)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ val: Double) -> JSONValue {
        return JSONValue.number(.fraction(val))
    }
}

extension NSNumber: JSONable {
    public class func fromJSON(_ json: JSONValue) -> NSNumber? {
        switch json {
        case let .number(n):
            switch n {
            case .int(let i): return NSNumber(value: i)
            case .fraction(let f): return NSNumber(value: f)
            }
        case let .bool(b):
            return NSNumber(value: b)
        case let .string(s):
            guard let n = Double(s) else {
                return nil
            }
            return NSNumber(value: n)
        default:
            return nil
        }
    }
    
    public class func toJSON(_ num: NSNumber) -> JSONValue {
        if num.isBool {
            return JSONValue.bool(num.boolValue)
        }
        else if num.isReal {
            return JSONValue.number(.fraction(num.doubleValue))
        }
        else {
            return JSONValue.number(.int(num.int64Value))
        }
    }
}

extension String: JSONable {
    public static func fromJSON(_ json: JSONValue) -> String? {
        switch json {
        case let .string(n):
            return n
        default:
            return nil
        }
    }
    
    public static func toJSON(_ str: String) -> JSONValue {
        return JSONValue.string(str)
    }
}

extension Date: JSONable {
    public static func fromJSON(_ json: JSONValue) -> Date? {
        switch json {
        case let .string(string):
            return Date(isoString: string)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ date: Date) -> JSONValue {
        return .string(date.isoString)
    }
}

extension NSDate: JSONable {
    public static func fromJSON(_ json: JSONValue) -> NSDate? {
        return Date.fromJSON(json) as NSDate?
    }
    
    public static func toJSON(_ date: NSDate) -> JSONValue {
        return Date.toJSON(date as Date)
    }
}

extension NSNull: JSONable {
    public class func fromJSON(_ json: JSONValue) -> NSNull? {
        switch json {
        case .null:
            return NSNull()
        default:
            return nil
        }
    }
    
    public class func toJSON(_ val: NSNull) -> JSONValue {
        return JSONValue.null
    }
}
