import XCTest
import JSONValueRX
@testable import AutoGraphQL

class DocumentTests: XCTestCase {
    var subject: AutoGraphQL.Document!
    
    func testGraphQLStringWithObjectFieldsFragments() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", selectionSet: [scalar1])
        
        let object = Object(name: "obj", alias: "cool_alias", selectionSet: [subobj, scalar2])
        let operation1 = AutoGraphQL.Operation(type: .query, name: "Query", selectionSet: [object])
        
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        let fragment = FragmentDefinition(name: "frag", type: "CoolType", directives: [directive], selectionSet: [scalar1, scalar2])
        
        let operation2 = AutoGraphQL.Operation(type: .mutation,
                                               name: "Mutation",
                                               selectionSet: [
                                                subobj,
                                                scalar2,
                                                Selection.object(
                                                    name: "object2",
                                                    alias: nil,
                                                    arguments: ["key" : "val"],
                                                    directives: nil,
                                                    selectionSet: [
                                                        "scalar",
                                                        Selection.scalar(name: "scalar", alias: "cool"),
                                                        Object(name: "object", selectionSet: ["objectScalar"])
                                                    ])])
        
        self.subject = AutoGraphQL.Document(operations: [operation1, operation2], fragments: [fragment!])
        XCTAssertEqual(try! self.subject.graphQLString(),
                       """
                       query Query {
                       cool_alias: obj {
                       cool_obj: subobj {
                       cool_scalar: scalar1
                       }
                       scalar2
                       }
                       }
                       mutation Mutation {
                       cool_obj: subobj {
                       cool_scalar: scalar1
                       }
                       scalar2
                       object2(key: \"val\") {
                       scalar
                       cool: scalar
                       object {
                       objectScalar
                       }
                       }
                       }
                       fragment frag on CoolType @cool(best: \"directive\") {\ncool_scalar: scalar1\nscalar2\n}
                       """
                       )
    }
}

class FieldTests: XCTestCase {
    
    class FieldMock: ScalarField {
        var directives: [Directive]?

        var name: String {
            return "mock"
        }
        
        var alias: String?
        func graphQLString() throws -> String {
            return "blah"
        }
    }
    
    var subject: FieldMock!
    
    override func setUp() {
        super.setUp()
        
        self.subject = FieldMock()
    }
    
    func testSerializeAlias() {
        XCTAssertEqual(try! self.subject.serializedAlias(), "")
        self.subject.alias = "field"
        XCTAssertEqual(try! self.subject.serializedAlias(), "field: ")
    }
}

class ScalarTests: XCTestCase {
    
    var subject: Scalar!
    
    func testGraphQLStringWithAlias() {
        self.subject = Scalar(name: "scalar", alias: "cool_alias")
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: scalar")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Scalar(name: "scalar", alias: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "scalar")
    }
    
    func testGraphQLStringAsLiteral() {
        XCTAssertEqual(try! "scalar".graphQLString(), "scalar")
    }
}

class ObjectTests: XCTestCase {
    
    var subject: Object!
    
    func testThrowsIfNoFieldsOrFragments() {
        self.subject = Object(name: "obj", alias: "cool_alias", selectionSet: [])
        XCTAssertThrowsError(try self.subject.graphQLString())
    }
    
    func testGraphQLStringWithAlias() {
        self.subject = Object(name: "obj", alias: "cool_alias", selectionSet: ["scalar"])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Object(name: "obj", alias: nil, selectionSet: ["scalar"])
        XCTAssertEqual(try! self.subject.graphQLString(), "obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", selectionSet: [scalar1, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", selectionSet: [scalar1])
        
        self.subject = Object(name: "obj", alias: "cool_alias", selectionSet: [subobj, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
}

class InlineFragmentTests: XCTestCase {
    var subject: InlineFragment!
    
    func testSelectionSetName() {
        let inlineFrag = InlineFragment(typeName: "Derp", selectionSet: [])
        XCTAssertEqual(inlineFrag.selectionSetName, "... on Derp")
    }
    
    func testInlineFragment() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let fragment = FragmentDefinition(name: "frag", type: "Fraggie", selectionSet: [scalar2])!
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        let inlineFrag = InlineFragment(typeName: "Derp", selectionSet: [scalar1])
        self.subject = InlineFragment(typeName: "InlineFrag", directives: [directive], selectionSet: [scalar1, FragmentSpread(fragment: fragment), inlineFrag])
        
        XCTAssertEqual(try! self.subject.graphQLString(), "... on InlineFrag @cool(best: \"directive\") {\ncool_scalar: scalar1\n...frag\n... on Derp {\ncool_scalar: scalar1\n}\n}")
    }
    
    func testObjectWithInlineFragment() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", selectionSet: [scalar1])
        let inlineFrag = InlineFragment(typeName: "Derp", selectionSet: [scalar1])
        
        let obj = Object(name: "obj", alias: "cool_alias", selectionSet: [inlineFrag, subobj, scalar2])
        XCTAssertEqual(try! obj.graphQLString(), "cool_alias: obj {\n... on Derp {\ncool_scalar: scalar1\n}\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
}

class SelectionSetTests: XCTestCase {
    var subject: SelectionSet!
    
    func testMergingSelections() {
        let scalar1: Selection = .scalar(name: "scalar1", alias: "alias")
        let scalar2: Selection = .scalar(name: "scalar2", alias: nil)
        let object: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [scalar1])
        let dupe: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [scalar2])
        
        try! self.subject = scalar1.merge(selection: object)
        try! self.subject.insert(dupe)
        XCTAssertEqual(self.subject.selectionSet.map { $0.key }, [scalar1.key, object.key])
    }
    
    func testMergingScalars() {
        let scalar1: Selection = .scalar(name: "scalar", alias: "alias")
        let scalar2: Selection = .scalar(name: "scalar", alias: nil)
        let scalar3: Selection = .scalar(name: "scalar", alias: nil)
        
        try! self.subject = scalar1.merge(selection: scalar2)
        try! self.subject.insert(scalar3)
        XCTAssertEqual(self.subject.selectionSet.map { $0.key }, [scalar1.key, scalar2.key])
    }
    
    func testMergingFragmentSpreads() {
        let fragment1: Selection = .fragmentSpread(name: "frag", directives: nil)
        let fragment2: Selection = .fragmentSpread(name: "frag", directives: nil)
        
        try! self.subject = fragment1.merge(selection: fragment2)
        XCTAssertEqual(self.subject.selectionSet.map { $0.key }, [fragment1.key])
    }
    
    func testMergingSelectionsOfSameKeyButDifferentTypeFails() {
        let scalar: Selection = .scalar(name: "key", alias: nil)
        let object: Selection = .object(name: "key", alias: nil, arguments: nil, directives: nil, selectionSet: [scalar])
        XCTAssertThrowsError(try scalar.merge(selection: object))
    }
    
    func testGraphQLString() {
        let scalar: Selection = .scalar(name: "scalar", alias: "alias")
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        
        let internalScalar: Selection = .scalar(name: "internalScalar", alias: nil)
        let internalInternalObject: Selection = .object(name: "internalInternalObject", alias: "anAlias", arguments: ["arg" : "value"], directives: nil, selectionSet: [internalScalar])
        let internalInlineFragment: Selection = .inlineFragment(namedType: "SomeType", directives: [directive], selectionSet: [internalInternalObject])
        let internalFragment: Selection = .fragmentSpread(name: "fraggie", directives: nil)
        let internalObject: Selection = .object(name: "internalObject", alias: nil, arguments: nil, directives: [directive], selectionSet: [internalScalar, internalInternalObject, internalFragment])
        
        let object: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [internalObject])
        let dupeObject: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [internalInlineFragment])
        
        let inlineFragmentScalar1: Selection = .scalar(name: "inlineFragmentScalar1", alias: "alias")
        let inlineFragmentScalar2: Selection = .scalar(name: "inlineFragmentScalar2", alias: nil)
        let inlineFragment1: Selection = .inlineFragment(namedType: nil, directives: nil, selectionSet: [inlineFragmentScalar1, inlineFragmentScalar2])
        let inlineFragment2: Selection = .inlineFragment(namedType: nil, directives: nil, selectionSet: [inlineFragmentScalar1])
        
        let selectionSet = SelectionSet([inlineFragment1, inlineFragment2, object, dupeObject, scalar])
        let gqlString = try! selectionSet.graphQLString()

        XCTAssertEqual(gqlString, " {\n" +
            "...  {\n" +
                "alias: inlineFragmentScalar1\n" +
                "inlineFragmentScalar2\n" +
            "}\n" +
            "object: object(arg: 1) {\n" +
                "internalObject @cool(best: \"directive\") {\n" +
                    "internalScalar\n" +
                    "anAlias: internalInternalObject(arg: \"value\") {\n" +
                        "internalScalar\n" +
                    "}\n" +
                    "...fraggie\n" +
                "}\n" +
                "... on SomeType @cool(best: \"directive\") {\n" +
                    "anAlias: internalInternalObject(arg: \"value\") {\n" +
                        "internalScalar\n" +
                    "}\n" +
                "}\n" +
            "}\n" +
            "alias: scalar\n" +
        "}")
    }
    
    func testSerializedSelections() {
        let scalar: Selection = .scalar(name: "scalar", alias: "alias")
        var selection: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [scalar])
        XCTAssertEqual(try! selection.serializedSelections(), ["alias: scalar"])
        
        selection = .scalar(name: "scalar", alias: "scalar")
        XCTAssertEqual(try! selection.serializedSelections(), [])
        
        selection = .fragmentSpread(name: "frag", directives: nil)
        XCTAssertEqual(try! selection.serializedSelections(), [])
        
        selection = .inlineFragment(namedType: nil, directives: nil, selectionSet: [scalar])
        XCTAssertEqual(try! selection.serializedSelections(), ["alias: scalar"])
    }
    
    func testKind() {
        var selection: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [])
        XCTAssertEqual(selection.kind, .object)
        
        selection = .scalar(name: "scalar", alias: "scalar")
        XCTAssertEqual(selection.kind, .scalar)
        
        selection = .fragmentSpread(name: "frag", directives: nil)
        XCTAssertEqual(selection.kind, .fragmentSpread)
        
        selection = .inlineFragment(namedType: nil, directives: nil, selectionSet: [])
        XCTAssertEqual(selection.kind, .inlineFragment)
    }
    
    func testSelectionSetName() {
        let selection: Selection = .scalar(name: "scalar", alias: "scalar")
        XCTAssertEqual(selection.selectionSetName, "scalar: scalar")
        
        let scalar1: Selection = .scalar(name: "scalar1", alias: "alias")
        let scalar2: Selection = .scalar(name: "scalar2", alias: "alias")
        let selectionSet = try! scalar1.merge(selection: scalar2)
        XCTAssertEqual(selectionSet.selectionSetName, "alias: scalar1, alias: scalar2")
    }
    
    func testKey() {
        var selection: Selection = .object(name: "object", alias: "object", arguments: ["arg" : 1], directives: nil, selectionSet: [])
        XCTAssertEqual(selection.key, "object: object")
        
        selection = .scalar(name: "scalar", alias: "scalar")
        XCTAssertEqual(selection.key, "scalar: scalar")
        
        selection = .scalar(name: "scalar", alias: nil)
        XCTAssertEqual(selection.key, "scalar")
        
        selection = .fragmentSpread(name: "frag", directives: nil)
        XCTAssertEqual(selection.key, "frag")
        
        selection = .inlineFragment(namedType: nil, directives: nil, selectionSet: [])
        XCTAssertEqual(selection.key, "... on ")
        
        selection = .inlineFragment(namedType: "name", directives: nil, selectionSet: [])
        XCTAssertEqual(selection.key, "... on name")
    }
}

class FragmentDefinitionTests: XCTestCase {
    var subject: FragmentDefinition!
    
    func testWithoutSelectionSetIsNil() {
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", selectionSet: [])
        XCTAssertNil(self.subject)
    }
    
    func testFragmentNamedOnIsNil() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        self.subject = FragmentDefinition(name: "on", type: "CoolType", selectionSet: [scalar1])
        XCTAssertNil(self.subject)
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", selectionSet: [scalar1, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", selectionSet: [scalar1])
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", selectionSet: [subobj, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
    
    func testGraphQLStringWithFragments() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let fragment1 = FragmentDefinition(name: "frag1", type: "Fraggie", selectionSet: [scalar1])!
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let fragment2 = FragmentDefinition(name: "frag2", type: "Freggie", selectionSet: [scalar2])!
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", selectionSet: [FragmentSpread(fragment: fragment1), FragmentSpread(fragment: fragment2)])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\n...frag1\n...frag2\n}")
    }
    
    func testGraphQLStringWithDirectives() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", directives: [directive], selectionSet: [scalar1, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType @cool(best: \"directive\") {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testSelectionSetName() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", selectionSet: [scalar1, scalar2])
        XCTAssertEqual(self.subject.selectionSetName, "frag")
    }
}

class OperationTests: XCTestCase {
    var subject: AutoGraphQL.Operation!
    
    func testQueryForms() {
        let scalar = Scalar(name: "name", alias: nil)
        self.subject = AutoGraphQL.Operation(type: .query, name: "Query", selectionSet: [scalar])
        XCTAssertEqual(try! self.subject.graphQLString(), "query Query {\nname\n}")
    }
    
    func testMutationForms() {
        let scalar = Scalar(name: "name", alias: nil)
        let variable = try! VariableDefinition<String>(name: "derp").typeErase()
        self.subject = AutoGraphQL.Operation(type: .mutation, name: "Mutation", variableDefinitions: [variable], selectionSet: [scalar])
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation($derp: String) {\nname\n}")
    }
    
    func testSubscriptionForms() {
        let scalar = Scalar(name: "name", alias: nil)
        let variable = try! VariableDefinition<String>(name: "derp").typeErase()
        self.subject = AutoGraphQL.Operation(type: .subscription, name: "Subscription", variableDefinitions: [variable], selectionSet: [scalar])
        XCTAssertEqual(try! self.subject.graphQLString(), "subscription Subscription($derp: String) {\nname\n}")
    }
    
    func testDirectives() {
        let scalar = Scalar(name: "name", alias: nil)
        let variable = try! VariableDefinition<String>(name: "derp").typeErase()
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        self.subject = AutoGraphQL.Operation(type: .mutation, name: "Mutation", variableDefinitions: [variable], directives: [directive], selectionSet: [scalar])
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation($derp: String) @cool(best: \"directive\") {\nname\n}")
    }
    
    func testVariableDefinitions() {
        struct UserInput: InputObjectValue {
            var fields: [String : InputValue] {
                return ["id" : 1234, "name" : "cool_user"]
            }
            
            static var objectTypeName: String {
                return "UserInput"
            }
        }
        
        enum UserEnumInput: InputValue {
            case myCase
            
            static func inputType() throws -> InputType {
                return .enumValue(typeName: "UserEnumInput")
            }
            
            func graphQLInputValue() throws -> String {
                switch self {
                case .myCase:
                    return try "MY_CASE".graphQLInputValue()
                }
            }
        }
        
        let stringVariable = VariableDefinition<String>(name: "stringVariable", defaultValue: "best_string")
        let variableVariable = VariableDefinition<VariableDefinition<String>>(name: "variableVariable")
        let objectVariable = VariableDefinition<UserInput>(name: "userInput")
        let nonOptionalListVariable = VariableDefinition<NonNullInputValue<[NonNullInputValue<Int>]>>(name: "nonOptionalListVariable")
        let optionalListObjectVariable = VariableDefinition<[UserInput]>(name: "optionalListObjectVariable")
        let enumVariable = VariableDefinition<UserEnumInput>(name: "enumVariable")
        
        self.subject = AutoGraphQL.Operation(type: .mutation,
                                             name: "Mutation",
                                             variableDefinitions: [
                                                try! stringVariable.typeErase(),
                                                try! variableVariable.typeErase(),
                                                try! objectVariable.typeErase(),
                                                try! nonOptionalListVariable.typeErase(),
                                                try! optionalListObjectVariable.typeErase(),
                                                try! enumVariable.typeErase()],
                                             selectionSet: ["name"])
        
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation($stringVariable: String = \"best_string\", $variableVariable: String, $userInput: UserInput, $nonOptionalListVariable: [Int!]!, $optionalListObjectVariable: [UserInput], $enumVariable: UserEnumInput) {\nname\n}")
    }
    
    func testVariableVariablesWithDefaultValuesFail() {
        let stringVariable = VariableDefinition<String>(name: "stringVariable")
        let variableVariable = VariableDefinition<VariableDefinition<String>>(name: "variableVariable", defaultValue: stringVariable)
        
        XCTAssertThrowsError(try variableVariable.typeErase())
    }
    
    func testSelectionSet() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "object1", alias: "cool_obj", selectionSet: [scalar1])
        
        self.subject = AutoGraphQL.Operation(type: .mutation,
                                             name: "Mutation",
                                             selectionSet: [
                                                subobj,
                                                scalar2,
                                                Selection.object(
                                                    name: "object2",
                                                    alias: nil,
                                                    arguments: ["key" : "val"],
                                                    directives: nil,
                                                    selectionSet: [
                                                        "scalar",
                                                        Selection.scalar(name: "scalar", alias: "cool"),
                                                        Object(name: "object", selectionSet: ["objectScalar"])
                                                    ])])
        
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation {\n" +
            "cool_obj: object1 {\n" +
            "cool_scalar: scalar1\n" +
            "}\n" +
            "scalar2\n" +
            "object2(key: \"val\") {\n" +
            "scalar\n" +
            "cool: scalar\n" +
            "object {\n" +
                "objectScalar\n" +
            "}\n" +
        "}\n" +
    "}")
    }
    
    func testInitializersOnSelectionTypeArray() {
        let fields: [Field] = ["scalar"]
        let _ = Object(name: "object", selectionSet: fields)
        let _ = AutoGraphQL.Operation(type: .query, name: "Query", selectionSet: fields)
        let _ = InlineFragment(typeName: "Derp", selectionSet: fields)
        let frag = FragmentDefinition(name: "frag", type: "Fraggie", selectionSet: fields)
        XCTAssertNotNil(frag)
    }
}

class InputValueTests: XCTestCase {
    
    func testArrayInputValue() {
        XCTAssertEqual(try Array<String>.inputType().typeName, "[String]")
        XCTAssertEqual(try! [ 1, "derp" ].graphQLInputValue(), "[1, \"derp\"]")
    }
    
    func testEmptyArrayInputValue() {
        XCTAssertEqual(try [].graphQLInputValue(), "[]")
    }
    
    func testDictionaryInputValue() {
        XCTAssertThrowsError(try Dictionary<String, String>.inputType())
        
        let value = try! [ "number" : 1, "string" : "derp" ].graphQLInputValue()
        XCTAssertTrue(value == "{number: 1, string: \"derp\"}" || value == "{string: \"derp\", number: 1}")
    }
    
    func testEmptyDictionaryInputValue() {
        XCTAssertEqual(try [:].graphQLInputValue(), "{}")
    }
    
    func testBoolInputValue() {
        XCTAssertEqual(try Bool.inputType().typeName, "Boolean")
        XCTAssertEqual(try true.graphQLInputValue(), "true")
    }
    
    func testIntInputValue() {
        XCTAssertEqual(try Int.inputType().typeName, "Int")
        XCTAssertEqual(try 1.graphQLInputValue(), "1")
    }
    
    func testDoubleInputValue() {
        XCTAssertEqual(try Double.inputType().typeName, "Float")
        
        // 1.1 -> "1.1000000000000001" https://bugs.swift.org/browse/SR-5961
        XCTAssertEqual(try (1.2 as Double).graphQLInputValue(), "1.2")
    }
    
    func testNSNullInputValue() {
        XCTAssertEqual(try NSNull.inputType().typeName, "Null")
        XCTAssertEqual(try NSNull().graphQLInputValue(), "null")
    }
    
    func testVariableInputValue() {
        let variable = VariableDefinition<String>(name: "variable")
        XCTAssertEqual(try type(of: variable).inputType().typeName, "String")
        XCTAssertEqual(try variable.graphQLInputValue(), "$variable")
    }
    
    func testNonNullInputValue() {
        let nonNull = NonNullInputValue<String>(inputValue: "val")
        XCTAssertEqual(try nonNull.graphQLInputValue(), "\"val\"")
        XCTAssertEqual(try type(of: nonNull).inputType().typeName, "String!")
    }
    
    func testIDInputValue() {
        var id = IDValue("blah")
        XCTAssertEqual(try id.graphQLInputValue(), "\"blah\"")
        
        id = IDValue(1)
        XCTAssertEqual(try id.graphQLInputValue(), "\"1\"")
        
        guard case .scalar(.id) = try! IDValue.inputType() else {
            XCTFail()
            return
        }
    }
    
    func testEnumInputValue() {
        XCTAssertThrowsError(try EnumValue<Color>(caseName: "null"))
        XCTAssertThrowsError(try EnumValue<Color>(caseName: "true"))
        XCTAssertThrowsError(try EnumValue<Color>(caseName: "false"))
        
        let enumVal = Color.red
        XCTAssertEqual(try enumVal.graphQLInputValue(), "RED")
        
        guard case .enumValue(typeName: "Color") = try! Color.inputType() else {
            XCTFail()
            return
        }
        
        let anyEnumVal = try! AnyEnumValue(caseName: "any")
        XCTAssertThrowsError(try AnyEnumValue.inputType())
        XCTAssertEqual(try anyEnumVal.graphQLInputValue(), "any")
    }
}

enum Color: String, EnumValueProtocol {
    case red = "RED"
    case blue = "BLUE"
    case green = "GREEN"
    
    func graphQLInputValue() throws -> String {
        return self.rawValue
    }
}

class VariableTest: XCTestCase {
    func testVariableInputValue() {
        let variable = Variable(name: "myVar")
        XCTAssertEqual(try variable.graphQLInputValue(), "$myVar")
    }
    
    func testVariableTypeThrows() {
        XCTAssertThrowsError(try Variable.inputType())
    }
}
