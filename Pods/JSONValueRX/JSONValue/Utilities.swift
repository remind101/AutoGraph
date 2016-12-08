import Foundation

extension NSNumber {
    public var isBool: Bool {
        let trueNumber = NSNumber(value: true as Bool)
        let falseNumber = NSNumber(value: false as Bool)
        let trueObjCType = String(cString: trueNumber.objCType)
        let falseObjCType = String(cString: falseNumber.objCType)
        
        let objCType = String(cString: self.objCType)
        let isTrueNumber = (self.compare(trueNumber) == ComparisonResult.orderedSame && objCType == trueObjCType)
        let isFalseNumber = (self.compare(falseNumber) == ComparisonResult.orderedSame && objCType == falseObjCType)
        
        return isTrueNumber || isFalseNumber
    }
}

extension Dictionary {
    func mapValues<OutValue>(_ transform: (Value) throws -> OutValue) rethrows -> [Key : OutValue] {
        var outDict = [Key : OutValue]()
        try self.forEach { (key, value) in
            outDict[key] = try transform(value)
        }
        return outDict
    }
}

// Consider using SwiftDate library if requirements increase.
public extension DateFormatter {
    @nonobjc public static let isoFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter
    }()
}

public extension Date {
    
    public init?(isoString: String) {
        let dateFormatter = DateFormatter.isoFormatter
        guard let date = dateFormatter.date(from: isoString) else {
            return nil
        }
        self = date
    }
    
    public var isoString: String {
        let dateFromatter = DateFormatter.isoFormatter
        return dateFromatter.string(from: self)
    }
}
