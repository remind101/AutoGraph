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
        
        
    }
}

class AutoGraph {
    func send(_ request: Request) {
        
    }
}

class FilmRequest {
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
