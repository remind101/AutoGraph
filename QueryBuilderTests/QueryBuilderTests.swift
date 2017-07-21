import XCTest
@testable import QueryBuilder

class FieldTests: XCTestCase {
    
    class FieldMock: Field {
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

class AcceptsFieldsTests: XCTestCase {
    
    class AcceptsFieldsMock: AcceptsFields {
        var fields: [Field]?
    }
    
    var subject: AcceptsFieldsMock!
    
    override func setUp() {
        super.setUp()
        
        self.subject = AcceptsFieldsMock()
    }
    
    func testSerializedFields() {
        XCTAssertEqual(try! self.subject.serializedFields(), "")
        
        let scalar1 = Scalar(name: "scalar1", alias: nil)
        let scalar2 = Scalar(name: "scalar2", alias: "derp")
        let object = Object(name: "obj", alias: "cool", arguments: ["key" : "value"], fields: [scalar2], fragments: nil)
        
        self.subject.fields = [ scalar1, object ]
        XCTAssertEqual(try! self.subject.serializedFields(), "scalar1\ncool: obj(key: \"value\") {\nderp: scalar2\n}")
    }
    
    func testSerializedFieldsWithDirectives() {
        XCTAssertEqual(try! self.subject.serializedFields(), "")
        
        let directive1 = Directive(name: "cool", arguments: ["best" : "directive"])
        let scalar1 = Scalar(name: "scalar1", alias: nil, directives: [directive1])
        let scalar2 = Scalar(name: "scalar2", alias: "derp")
        let objDirective = Directive(name: "obj", arguments: ["best" : "objDirective"])
        let object = Object(name: "obj", alias: "cool", arguments: ["key" : "value"], fields: [scalar2], fragments: nil, directives: [objDirective])
        
        self.subject.fields = [ scalar1, object ]
        XCTAssertEqual(try! self.subject.serializedFields(), "scalar1 @cool(best: \"directive\")\ncool: obj(key: \"value\") @obj(best: \"objDirective\") {\nderp: scalar2\n}")
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
        self.subject = Object(name: "obj", alias: "cool_alias")
        XCTAssertThrowsError(try self.subject.graphQLString())
    }
    
    func testGraphQLStringWithAlias() {
        self.subject = Object(name: "obj", alias: "cool_alias", fields: ["scalar"])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Object(name: "obj", alias: nil, fields: ["scalar"])
        XCTAssertEqual(try! self.subject.graphQLString(), "obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [scalar1, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1])
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [subobj, scalar2])
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
}

class InlineFragmentTests: XCTestCase {
    var subject: InlineFragment!
    
    func testInlineFragment() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let fragment = FragmentDefinition(name: "frag", type: "Fraggie", fields: [scalar2], fragments: nil)!
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        let inlineFrag = InlineFragment(typeName: "Derp", fields: [scalar1])
        self.subject = InlineFragment(typeName: "InlineFrag", directives: [directive], fields: [scalar1], fragments: [FragmentSpread(fragment: fragment)], inlineFragments: [inlineFrag])
        
        XCTAssertEqual(try! self.subject.graphQLString(), "... on InlineFrag @cool(best: \"directive\") {\ncool_scalar: scalar1\n...frag\n... on Derp {\ncool_scalar: scalar1\n}\n}")
    }
    
    func testObjectWithInlineFragment() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1])
        let inlineFrag = InlineFragment(typeName: "Derp", fields: [scalar1])
        
        let obj = Object(name: "obj", alias: "cool_alias", fields: [subobj, scalar2], inlineFragments: [inlineFrag])
        XCTAssertEqual(try! obj.graphQLString(), "cool_alias: obj {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n... on Derp {\ncool_scalar: scalar1\n}\n}")
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
        XCTAssertEqual(self.subject.selectionSet.map { $0.key }, [object.key, scalar1.key])
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
            "... on SomeType @cool(best: \"directive\") {\n" +
            "anAlias: internalInternalObject(arg: \"value\") {\n" +
            "internalScalar\n" +
            "}\n" +
            "}\n" +
            "internalObject @cool(best: \"directive\") {\n" +
            "...fraggie\n" +
            "internalScalar\n" +
            "anAlias: internalInternalObject(arg: \"value\") {\n" +
            "internalScalar\n" +
            "}\n" +
            "}\n" +
            "}\n" +
            "alias: scalar\n" +
    "}")
    }
}

class FragmentDefinitionTests: XCTestCase {
    var subject: FragmentDefinition!
    
    func testWithoutSelectionSetIsNil() {
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", fields: nil, fragments: nil)
        XCTAssertNil(self.subject)
    }
    
    func testFragmentNamedOnIsNil() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        self.subject = FragmentDefinition(name: "on", type: "CoolType", fields: [scalar1], fragments: nil)
        XCTAssertNil(self.subject)
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", fields: [scalar1, scalar2], fragments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1])
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", fields: [subobj, scalar2], fragments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
    
    func testGraphQLStringWithFragments() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let fragment1 = FragmentDefinition(name: "frag1", type: "Fraggie", fields: [scalar1], fragments: nil)!
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let fragment2 = FragmentDefinition(name: "frag2", type: "Freggie", fields: [scalar2], fragments: nil)!
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", fields: nil, fragments: [FragmentSpread(fragment: fragment1), FragmentSpread(fragment: fragment2)])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType {\n...frag1\n...frag2\n}")
    }
    
    func testGraphQLStringWithDirectives() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        
        self.subject = FragmentDefinition(name: "frag", type: "CoolType", fields: [scalar1, scalar2], fragments: nil, directives: [directive])
        XCTAssertEqual(try! self.subject.graphQLString(), "fragment frag on CoolType @cool(best: \"directive\") {\ncool_scalar: scalar1\nscalar2\n}")
    }
}

class OperationTests: XCTestCase {
    var subject: QueryBuilder.Operation!
    
    func testQueryForms() {
        let scalar = Scalar(name: "name", alias: nil)
        self.subject = QueryBuilder.Operation(type: .query, name: "Query", fields: [scalar], fragments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "query Query {\nname\n}")
    }
    
    func testMutationForms() {
        let scalar = Scalar(name: "name", alias: nil)
        let variable = try! VariableDefinition<String>(name: "derp").typeErase()
        self.subject = QueryBuilder.Operation(type: .mutation, name: "Mutation", variableDefinitions: [variable], fields: [scalar], fragments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation($derp: String) {\nname\n}")
    }
    
    func testDirectives() {
        let scalar = Scalar(name: "name", alias: nil)
        let variable = try! VariableDefinition<String>(name: "derp").typeErase()
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        self.subject = QueryBuilder.Operation(type: .mutation, name: "Mutation", variableDefinitions: [variable], fields: [scalar], fragments: nil, directives: [directive])
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
        
        self.subject = QueryBuilder.Operation(type: .mutation,
                                              name: "Mutation",
                                              variableDefinitions: [
                                                try! stringVariable.typeErase(),
                                                try! variableVariable.typeErase(),
                                                try! objectVariable.typeErase(),
                                                try! nonOptionalListVariable.typeErase(),
                                                try! optionalListObjectVariable.typeErase(),
                                                try! enumVariable.typeErase()
            ],
                                              fields: ["name"],
                                              fragments: nil
                                              )
        
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation($stringVariable: String = \"best_string\", $variableVariable: String, $userInput: UserInput, $nonOptionalListVariable: [Int!]!, $optionalListObjectVariable: [UserInput], $enumVariable: UserEnumInput) {\nname\n}")
    }
    
    func testVariableVariablesWithDefaultValuesFail() {
        let stringVariable = VariableDefinition<String>(name: "stringVariable")
        let variableVariable = VariableDefinition<VariableDefinition<String>>(name: "variableVariable", defaultValue: stringVariable)
        
        XCTAssertThrowsError(try variableVariable.typeErase())
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
        XCTAssertEqual(try! [ "number" : 1, "string" : "derp" ].graphQLInputValue(), "{number: 1, string: \"derp\"}")
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
        XCTAssertEqual(try (1.1 as Double).graphQLInputValue(), "1.1")
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
}
