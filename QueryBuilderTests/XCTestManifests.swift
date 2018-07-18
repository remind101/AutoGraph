import XCTest

extension DocumentTests {
    static let __allTests = [
        ("testGraphQLStringWithObjectFieldsFragments", testGraphQLStringWithObjectFieldsFragments),
    ]
}

extension FieldTests {
    static let __allTests = [
        ("testSerializeAlias", testSerializeAlias),
    ]
}

extension FoundationExtensionsTests {
    static let __allTests = [
        ("testArgumentStringJsonEncodes", testArgumentStringJsonEncodes),
        ("testNSNullJsonEncodes", testNSNullJsonEncodes),
        ("testNSNumberJsonEncodes", testNSNumberJsonEncodes),
    ]
}

extension FragmentDefinitionTests {
    static let __allTests = [
        ("testFragmentNamedOnIsNil", testFragmentNamedOnIsNil),
        ("testGraphQLStringWithDirectives", testGraphQLStringWithDirectives),
        ("testGraphQLStringWithFragments", testGraphQLStringWithFragments),
        ("testGraphQLStringWithObjectFields", testGraphQLStringWithObjectFields),
        ("testGraphQLStringWithScalarFields", testGraphQLStringWithScalarFields),
        ("testSelectionSetName", testSelectionSetName),
        ("testWithoutSelectionSetIsNil", testWithoutSelectionSetIsNil),
    ]
}

extension InlineFragmentTests {
    static let __allTests = [
        ("testInlineFragment", testInlineFragment),
        ("testObjectWithInlineFragment", testObjectWithInlineFragment),
        ("testSelectionSetName", testSelectionSetName),
    ]
}

extension InputValueTests {
    static let __allTests = [
        ("testArrayInputValue", testArrayInputValue),
        ("testBoolInputValue", testBoolInputValue),
        ("testDictionaryInputValue", testDictionaryInputValue),
        ("testDoubleInputValue", testDoubleInputValue),
        ("testEmptyArrayInputValue", testEmptyArrayInputValue),
        ("testEmptyDictionaryInputValue", testEmptyDictionaryInputValue),
        ("testEnumInputValue", testEnumInputValue),
        ("testIDInputValue", testIDInputValue),
        ("testIntInputValue", testIntInputValue),
        ("testNonNullInputValue", testNonNullInputValue),
        ("testNSNullInputValue", testNSNullInputValue),
        ("testVariableInputValue", testVariableInputValue),
    ]
}

extension ObjectTests {
    static let __allTests = [
        ("testGraphQLStringWithAlias", testGraphQLStringWithAlias),
        ("testGraphQLStringWithObjectFields", testGraphQLStringWithObjectFields),
        ("testGraphQLStringWithoutAlias", testGraphQLStringWithoutAlias),
        ("testGraphQLStringWithScalarFields", testGraphQLStringWithScalarFields),
        ("testThrowsIfNoFieldsOrFragments", testThrowsIfNoFieldsOrFragments),
    ]
}

extension OperationTests {
    static let __allTests = [
        ("testDirectives", testDirectives),
        ("testInitializersOnSelectionTypeArray", testInitializersOnSelectionTypeArray),
        ("testMutationForms", testMutationForms),
        ("testQueryForms", testQueryForms),
        ("testSelectionSet", testSelectionSet),
        ("testSubscriptionForms", testSubscriptionForms),
        ("testVariableDefinitions", testVariableDefinitions),
        ("testVariableVariablesWithDefaultValuesFail", testVariableVariablesWithDefaultValuesFail),
    ]
}

extension OrderedDictionaryTests {
    static let __allTests = [
        ("testsMaintainsOrder", testsMaintainsOrder),
    ]
}

extension ScalarTests {
    static let __allTests = [
        ("testGraphQLStringAsLiteral", testGraphQLStringAsLiteral),
        ("testGraphQLStringWithAlias", testGraphQLStringWithAlias),
        ("testGraphQLStringWithoutAlias", testGraphQLStringWithoutAlias),
    ]
}

extension SelectionSetTests {
    static let __allTests = [
        ("testGraphQLString", testGraphQLString),
        ("testKey", testKey),
        ("testKind", testKind),
        ("testMergingFragmentSpreads", testMergingFragmentSpreads),
        ("testMergingScalars", testMergingScalars),
        ("testMergingSelections", testMergingSelections),
        ("testMergingSelectionsOfSameKeyButDifferentTypeFails", testMergingSelectionsOfSameKeyButDifferentTypeFails),
        ("testSelectionSetName", testSelectionSetName),
        ("testSerializedSelections", testSerializedSelections),
    ]
}

extension VariableTest {
    static let __allTests = [
        ("testVariableInputValue", testVariableInputValue),
        ("testVariableTypeThrows", testVariableTypeThrows),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DocumentTests.__allTests),
        testCase(FieldTests.__allTests),
        testCase(FoundationExtensionsTests.__allTests),
        testCase(FragmentDefinitionTests.__allTests),
        testCase(InlineFragmentTests.__allTests),
        testCase(InputValueTests.__allTests),
        testCase(ObjectTests.__allTests),
        testCase(OperationTests.__allTests),
        testCase(OrderedDictionaryTests.__allTests),
        testCase(ScalarTests.__allTests),
        testCase(SelectionSetTests.__allTests),
        testCase(VariableTest.__allTests),
    ]
}
#endif
