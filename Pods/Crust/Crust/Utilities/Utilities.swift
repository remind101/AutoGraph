public extension Collection where Iterator.Element: Equatable {
    static func defaultUniquingFunctions() -> UniquingFunctions<Iterator.Element, Self> {
        let equality: (Iterator.Element) -> (Iterator.Element) -> Bool = { obj in
        { compared in
            obj == compared
            }
        }
        
        return (equality, Self.firstIndex(of:), Self.contains)
    }
}

public extension Array where Iterator.Element: MappingKey {
    func anyKeyCollection<TargetKey: MappingKey>() -> AnyKeyCollection<TargetKey>? {
        return AnyKeyCollection(self) as? AnyKeyCollection<TargetKey>
    }
}
