import XCTest
import Alamofire
import Crust
import Realm
import QueryBuilder
@testable import AutoGraph

class AutoGraphTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func testFileMapping() {
        let stub = AllFilmsStub()
        stub.registerStub()
        
        AutoGraph.send(FilmRequest())
        
        waitFor(delay: 1.0)
        
        print("here")
    }
    
    func waitFor(delay: TimeInterval) {
        let expectation = self.expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: delay + 1.0, handler: { error in
            if let error = error {
                print(error)
            }
        })
    }
}

class AutoGraph {
    static let url = "http://localhost:8080/graphql"
    class func send(_ request: FilmRequest) {
        
        Alamofire.request(url, parameters: ["query" : request.query.graphQLString]).responseJSON { response in
            print(response.request!)  // original URL request
            print(response.response!) // HTTP URL response
            print(response.data!)     // server data
            print(response.result)   // result of response serialization
            
            if let JSON = response.result.value {
                print("JSON: \(JSON)")
            }
        }
    }
}

class FilmRequest {
    /*
    "query {" +
        "allFilms {" +
            "films {" +
                "title" +
                "episodeID" +
                "openingCrawl" +
                "director" +
            "}" +
        "}" +
    "}"
    */
    
    let query = QueryBuilder.Operation(type: .query,
                                       name: "filmRequest",
                                       fields: [
                                        Object(name: "allFilms",
                                               alias: nil,
                                               fields: [
                                                Object(name: "films",
                                                       alias: nil,
                                                       fields: [
                                                        Scalar(name: "title", alias: nil),
                                                        Scalar(name: "episodeID", alias: nil),
                                                        Scalar(name: "openingCrawl", alias: nil),
                                                        Scalar(name: "director", alias: nil)],
                                                       fragments: nil,
                                                       arguments: nil)],
                                               fragments: nil,
                                               arguments: nil)
                                        ],
                                       fragments: nil,
                                       arguments: nil)
    
    func mapping() -> FilmMapping {
        let adaptor = RealmAdaptor(realm: RLMRealm.default())
        return FilmMapping(adaptor: adaptor)
    }
}

class FilmMapping: RealmMapping {
    public var adaptor: RealmAdaptor
    public var primaryKeys: [String : Keypath]? {
        return [ "remoteId" : "uuid" ]
    }
    
    public required init(adaptor: RealmAdaptor) {
        self.adaptor = adaptor
    }
    
    public func mapping(tomap: inout Film, context: MappingContext) {
        
        tomap.remoteId  <- "id"         >*<
        tomap.title     <- "title"      >*<
        tomap.episode   <- "episode"    >*<
        tomap.openingCrawl  <- "openingCrawl"   >*<
        tomap.director      <- "director"       >*<
        context
    }
}

class AllFilmsStub: Stub {
    override var jsonFixtureFile: String? {
        get { return "AllFilms" }
        set { }
    }
    
    override var urlPath: String? {
        get { return "/graphql" }
        set { }
    }
    
    override var graphQLQuery: String {
        get {
            return "query filmRequest {\n" +
                        "allFilms {\n" +
                            "films {\n" +
                                "title\n" +
                                "episodeID\n" +
                                "openingCrawl\n" +
                                "director\n" +
                            "}\n" +
                        "}\n" +
                    "}\n"
        }
        set { }
    }
}
