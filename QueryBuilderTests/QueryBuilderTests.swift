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
        let object = Object(name: "obj", alias: "cool", fields: [scalar2], fragments: nil, arguments: ["key" : "value"])
        
        self.subject.fields = [ scalar1, object ]
        XCTAssertEqual(try! self.subject.serializedFields(), "scalar1\ncool: obj(key: \"value\") {\nderp: scalar2\n}")
    }
    
    func testSerializedFieldsWithDirectives() {
        XCTAssertEqual(try! self.subject.serializedFields(), "")
        
        let directive1 = Directive(name: "cool", arguments: ["best" : "directive"])
        let scalar1 = Scalar(name: "scalar1", alias: nil, directives: [directive1])
        let scalar2 = Scalar(name: "scalar2", alias: "derp")
        let objDirective = Directive(name: "obj", arguments: ["best" : "objDirective"])
        let object = Object(name: "obj", alias: "cool", fields: [scalar2], fragments: nil, arguments: ["key" : "value"], directives: [objDirective])
        
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
        self.subject = Object(name: "obj", alias: "cool_alias", fields: ["scalar"], fragments: nil, arguments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Object(name: "obj", alias: nil, fields: ["scalar"], fragments: nil, arguments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "obj {\nscalar\n}")
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [scalar1, scalar2], fragments: nil, arguments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1], fragments: nil, arguments: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [subobj, scalar2], fragments: nil, arguments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "cool_alias: obj {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
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
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1], fragments: nil, arguments: nil)
        
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
        self.subject = QueryBuilder.Operation(type: .query, name: "Query", fields: [scalar], fragments: nil, arguments: nil)
        XCTAssertEqual(try! self.subject.graphQLString(), "query Query {\nname\n}")
    }
    
    func testMutationForms() {
        let scalar = Scalar(name: "name", alias: nil)
        self.subject = QueryBuilder.Operation(type: .mutation, name: "Mutation", fields: [scalar], fragments: nil, arguments: ["name" : "olga"])
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation(name: \"olga\") {\nname\n}")
    }
    
    func testDirectives() {
        let scalar = Scalar(name: "name", alias: nil)
        let directive = Directive(name: "cool", arguments: ["best" : "directive"])
        self.subject = QueryBuilder.Operation(type: .mutation, name: "Mutation", fields: [scalar], fragments: nil, arguments: ["name" : "olga"], directives: [directive])
        XCTAssertEqual(try! self.subject.graphQLString(), "mutation Mutation(name: \"olga\") @cool(best: \"directive\") {\nname\n}")
    }
}

class InputValueTests: XCTestCase {
    
    func testArrayInputValue() {
        XCTAssertEqual(try! [ 1, "derp" ].graphQLInputValue(), "[1, \"derp\"]")
    }
    
    func testEmptyArrayInputValue() {
        XCTAssertEqual(try [].graphQLInputValue(), "[]")
    }
    
    func testDictionaryInputValue() {
        XCTAssertEqual(try! [ "number" : 1, "string" : "derp" ].graphQLInputValue(), "{number: 1, string: \"derp\"}")
    }
    
    func testEmptyDictionaryInputValue() {
        XCTAssertEqual(try [:].graphQLInputValue(), "{}")
    }
}
