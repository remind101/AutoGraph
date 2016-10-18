import Foundation

extension String: Argument {
    public var graphQLArgument: String {
        return self.quoted
    }
    
    public var quoted: String {
        return "\"\(self)\""
    }
    
    // TODO: At somepoint we can "verifyNoWhitespace" and throw an error instead.
    var withoutWhitespace: String {
        return self.replace(" ", with: "")
    }
    
    private func replace(_ string: String, with replacement: String) -> String {
        return self.replacingOccurrences(of: string, with: replacement, options: NSString.CompareOptions.literal, range: nil)
    }
}

extension Int: Argument {
    public var graphQLArgument: String {
        return String(self)
    }
}
