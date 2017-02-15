import Foundation

extension String: Argument {
    public func graphQLArgument() throws -> String {
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

extension Int: Argument {
    public func graphQLArgument() throws -> String {
        return try self.jsonEncodedString()
    }
}
