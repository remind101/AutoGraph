import XCTest
@testable import QueryBuilder

class FieldTests: XCTestCase {
    
    class FieldMock: Field {
        var name: String {
            return "mock"
        }
        var alias: String?
        var graphQLString: String {
            return "blah"
        }
    }
    
    var subject: FieldMock!
    
    override func setUp() {
        super.setUp()
        
        self.subject = FieldMock()
    }
    
    func testSerializeAlias() {
        XCTAssertEqual(self.subject.serializedAlias, "")
        self.subject.alias = "field"
        XCTAssertEqual(self.subject.serializedAlias, "field: ")
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
        XCTAssertEqual(self.subject.serializedFields, "")
        
        let scalar1 = Scalar(name: "scalar1", alias: nil)
        let scalar2 = Scalar(name: "scalar2", alias: "derp")
        let object = Object(name: "obj", alias: "cool", fields: [scalar2], fragments: nil, arguments: [("key", "value")])
        
        self.subject.fields = [ scalar1, object ]
        XCTAssertEqual(self.subject.serializedFields, "scalar1\ncool: obj(key: \"value\") {\nderp: scalar2\n}")
    }
}

class ScalarTests: XCTestCase {
    
    var subject: Scalar!
    
    func testGraphQLStringWithAlias() {
        self.subject = Scalar(name: "scalar", alias: "cool_alias")
        XCTAssertEqual(self.subject.graphQLString, "cool_alias: scalar")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Scalar(name: "scalar", alias: nil)
        XCTAssertEqual(self.subject.graphQLString, "scalar")
    }
}

class ObjectTests: XCTestCase {
    
    var subject: Object!
    
    func testGraphQLStringWithAlias() {
        self.subject = Object(name: "obj", alias: "cool_alias", fields: nil, fragments: nil, arguments: nil)
        XCTAssertEqual(self.subject.graphQLString, "cool_alias: obj")
    }
    
    func testGraphQLStringWithoutAlias() {
        self.subject = Object(name: "obj", alias: nil, fields: nil, fragments: nil, arguments: nil)
        XCTAssertEqual(self.subject.graphQLString, "obj")
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [scalar1, scalar2], fragments: nil, arguments: nil)
        XCTAssertEqual(self.subject.graphQLString, "cool_alias: obj {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1], fragments: nil, arguments: nil)
        
        self.subject = Object(name: "obj", alias: "cool_alias", fields: [subobj, scalar2], fragments: nil, arguments: nil)
        XCTAssertEqual(self.subject.graphQLString, "cool_alias: obj {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
}

class FragmentTests: XCTestCase {
    var subject: Fragment!
    
    func testWithoutSelectionSetIsNil() {
        self.subject = Fragment(name: "frag", type: "CoolType", fields: nil, fragments: nil)
        XCTAssertNil(self.subject)
    }
    
    func testFragmentNamedOnIsNil() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        self.subject = Fragment(name: "on", type: "CoolType", fields: [scalar1], fragments: nil)
        XCTAssertNil(self.subject)
    }
    
    func testGraphQLStringWithScalarFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        
        self.subject = Fragment(name: "frag", type: "CoolType", fields: [scalar1, scalar2], fragments: nil)
        XCTAssertEqual(self.subject.graphQLString, "fragment frag on CoolType {\ncool_scalar: scalar1\nscalar2\n}")
    }
    
    func testGraphQLStringWithObjectFields() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let subobj = Object(name: "subobj", alias: "cool_obj", fields: [scalar1], fragments: nil, arguments: nil)
        
        self.subject = Fragment(name: "frag", type: "CoolType", fields: [subobj, scalar2], fragments: nil)
        XCTAssertEqual(self.subject.graphQLString, "fragment frag on CoolType {\ncool_obj: subobj {\ncool_scalar: scalar1\n}\nscalar2\n}")
    }
    
    func testGraphQLStringWithFragments() {
        let scalar1 = Scalar(name: "scalar1", alias: "cool_scalar")
        let fragment1 = Fragment(name: "frag1", type: "Fraggie", fields: [scalar1], fragments: nil)!
        let scalar2 = Scalar(name: "scalar2", alias: nil)
        let fragment2 = Fragment(name: "frag2", type: "Freggie", fields: [scalar2], fragments: nil)!
        
        self.subject = Fragment(name: "frag", type: "CoolType", fields: nil, fragments: [fragment1, fragment2])
        XCTAssertEqual(self.subject.graphQLString, "fragment frag on CoolType {\n...frag1\n...frag2\n}")
    }
}
