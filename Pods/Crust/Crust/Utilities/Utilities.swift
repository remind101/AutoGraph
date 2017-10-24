public extension Collection where Iterator.Element: Equatable {
    public static func defaultUniquingFunctions() -> UniquingFunctions<Iterator.Element, Self> {
        let equality: (Iterator.Element) -> (Iterator.Element) -> Bool = { obj in
        { compared in
            obj == compared
            }
        }
        
        return (equality, Self.index(of:), Self.contains)
    }
}

public extension Sequence where Iterator.Element: MappingKey {
    public func anyKeyCollection<TargetKey: MappingKey>() -> AnyKeyCollection<TargetKey>? {
        return AnyKeyCollection(self) as? AnyKeyCollection<TargetKey>
    }
}
