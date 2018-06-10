import Foundation

// MARK: - JSONable

public protocol JSONDecodable {
    associatedtype ConversionType = Self
    static func fromJSON(_ x: JSONValue) -> ConversionType?
}

public protocol JSONEncodable {
    associatedtype ConversionType
    static func toJSON(_ x: ConversionType) -> JSONValue
}

public protocol JSONable: JSONDecodable, JSONEncodable { }

extension Dictionary: JSONable {
    public typealias ConversionType = Dictionary<String, Value>
    public static func fromJSON(_ x: JSONValue) -> Dictionary.ConversionType? {
        switch x {
        case .object:
            return x.values() as? Dictionary<String, Value>
        default:
            return nil
        }
    }
    
    public static func toJSON(_ x: Dictionary.ConversionType) -> JSONValue {
        do {
            return try JSONValue(dict: x)
        } catch {
            return JSONValue.null
        }
    }
}

protocol AcceptsDouble {
    init(_ other: Double)
    static var maxDouble: Double { get }
    static var minDouble: Double { get }
}

extension AcceptsDouble {
    init?(safe double: Double) {
        guard double > Self.minDouble && double < Self.maxDouble else {
            return nil
        }
        self = Self(double)
    }
}

extension Int: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension Int8: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension Int16: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension Int32: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension Int64: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension UInt: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension UInt8: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension UInt16: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension UInt32: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}
extension UInt64: AcceptsDouble {
    static var maxDouble: Double {
        return Double(self.max)
    }
    static var minDouble: Double {
        return Double(self.min)
    }
}

struct ArrayMappingHelper<T: AcceptsDouble> {
    func map(arr: [JSONValue]) -> [Any]? {
        return try? arr.map {
            guard case let val as Double = $0.values() else {
                throw NSError()
            }
            guard let result = T(safe: val) else {
                throw NSError()
            }
            return result
        }
    }
}

extension Array: JSONable {
    public static func fromJSON(_ x: JSONValue) -> Array? {
        switch x {
        case let .array(xs):
            // TODO: Swift may have fixed integer overflow issues. Consider removing.
            switch Element.self {
            case is Int.Type:
                let help = ArrayMappingHelper<Int>()
                return help.map(arr: xs) as? Array
            case is Int8.Type:
                let help = ArrayMappingHelper<Int8>()
                return help.map(arr: xs) as? Array
            case is Int16.Type:
                let help = ArrayMappingHelper<Int16>()
                return help.map(arr: xs) as? Array
            case is Int32.Type:
                let help = ArrayMappingHelper<Int32>()
                return help.map(arr: xs) as? Array
            case is Int64.Type:
                let help = ArrayMappingHelper<Int64>()
                return help.map(arr: xs) as? Array
            case is UInt.Type:
                let help = ArrayMappingHelper<Int>()
                return help.map(arr: xs) as? Array
            case is UInt8.Type:
                let help = ArrayMappingHelper<Int8>()
                return help.map(arr: xs) as? Array
            case is UInt16.Type:
                let help = ArrayMappingHelper<Int16>()
                return help.map(arr: xs) as? Array
            case is UInt32.Type:
                let help = ArrayMappingHelper<Int32>()
                return help.map(arr: xs) as? Array
            case is UInt64.Type:
                let help = ArrayMappingHelper<Int64>()
                return help.map(arr: xs) as? Array
                
            default:
                return x.values() as? Array
            }
            
        default:
            return nil
        }
    }
    
    public static func toJSON(_ x: Array) -> JSONValue {
        do {
            return try JSONValue(array: x)
        } catch {
            return JSONValue.null
        }
    }
}

extension Bool: JSONable {
    public static func fromJSON(_ x: JSONValue) -> Bool? {
        switch x {
        case let .bool(n):
            return n
        case .number(0):
            return false
        case .number(1):
            return true
        default:
            return nil
        }
    }
    
    public static func toJSON(_ xs: Bool) -> JSONValue {
        return JSONValue.bool(xs)
    }
}

extension Int: JSONable {
    public static func fromJSON(_ x: JSONValue) -> Int? {
        switch x {
        case let .number(n):
            return Int(n)
        case let .string(s):
            return Int(s)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ xs: Int) -> JSONValue {
        return JSONValue.number(Double(xs))
    }
}

extension Double: JSONable {
    public static func fromJSON(_ x: JSONValue) -> Double? {
        switch x {
        case let .number(n):
            return n
        case let .string(s):
            return Double(s)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ xs: Double) -> JSONValue {
        return JSONValue.number(xs)
    }
}

extension NSNumber: JSONable {
    public class func fromJSON(_ x: JSONValue) -> NSNumber? {
        switch x {
        case let .number(n):
            return NSNumber(value: n as Double)
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
    
    public class func toJSON(_ x: NSNumber) -> JSONValue {
        if x.isBool {
            return JSONValue.bool(x.boolValue)
        }
        else {
            return JSONValue.number(x.doubleValue)
        }
    }
}

extension String: JSONable {
    public static func fromJSON(_ x: JSONValue) -> String? {
        switch x {
        case let .string(n):
            return n
        default:
            return nil
        }
    }
    
    public static func toJSON(_ x: String) -> JSONValue {
        return JSONValue.string(x)
    }
}

extension Date: JSONable {
    public static func fromJSON(_ x: JSONValue) -> Date? {
        switch x {
        case let .string(string):
            return Date(isoString: string)
        default:
            return nil
        }
    }
    
    public static func toJSON(_ x: Date) -> JSONValue {
        return .string(x.isoString)
    }
}

extension NSDate: JSONable {
    public static func fromJSON(_ x: JSONValue) -> NSDate? {
        return Date.fromJSON(x) as NSDate?
    }
    
    public static func toJSON(_ x: NSDate) -> JSONValue {
        return Date.toJSON(x as Date)
    }
}

extension NSNull: JSONable {
    public class func fromJSON(_ x: JSONValue) -> NSNull? {
        switch x {
        case .null:
            return NSNull()
        default:
            return nil
        }
    }
    
    public class func toJSON(_ xs: NSNull) -> JSONValue {
        return JSONValue.null
    }
}
