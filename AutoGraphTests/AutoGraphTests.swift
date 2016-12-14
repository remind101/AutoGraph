import XCTest
@testable import AutoGraph

class AutoGraphTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

class AllFilmsStub: Stub {
    override var jsonFixtureFile: String? {
        get {
            return "AllFilms"
        }
        set { }
    }
    
    override var graphQLQuery: String {
        get {
            return "query {" +
                        "allFilms {" +
                            "films {" +
                                "title" +
                                "episodeID" +
                                "openingCrawl" +
                                "director" +
                            "}" +
                        "}" +
                    "}"
        }
        set { }
    }
}
