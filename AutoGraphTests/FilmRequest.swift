import JSONValueRX
import Crust
import Realm
@testable import AutoGraphQL

class FilmRequest: Request {
    /*
     query film {
        film(id: "ZmlsbXM6MQ==") {
            title
            episodeID
            director
            openingCrawl
        }
     }
     */
    
    let query = Operation(type: .query,
                          name: "film",
                          fields: [
                            Object(name: "film",
                                   alias: nil,
                                   fields: [
                                    "id",
                                    Scalar(name: "title", alias: nil),
                                    Scalar(name: "episodeID", alias: nil),
                                    Scalar(name: "director", alias: nil),
                                    Scalar(name: "openingCrawl", alias: nil)],
                                   arguments: ["id" : "ZmlsbXM6MQ=="])
                            ],
                          fragments: nil)
    
    var mapping: Binding<FilmMapping> {
        return Binding.mapping("data.film", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default())))
    }
    
    var threadAdapter: RealmThreadAdaptor? {
        return RealmThreadAdaptor()
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

class FilmMapping: RealmMapping {
    
    public var adapter: RealmAdapter
    
    public var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return [ ("remoteId", "id", nil) ]
    }
    
    public required init(adapter: RealmAdapter) {
        self.adapter = adapter
    }
    
    public func mapping(toMap: inout Film, context: MappingContext) {
        toMap.title         <- ("title", context)
        toMap.episode       <- ("episodeID", context)
        toMap.openingCrawl  <- ("openingCrawl", context)
        toMap.director      <- ("director", context)
    }
}

class FilmStub: Stub {
    override var jsonFixtureFile: String? {
        get { return "Film" }
        set { }
    }
    
    override var urlPath: String? {
        get { return "/graphql" }
        set { }
    }
    
    override var graphQLQuery: String {
        get {
            return "query film {\n" +
                        "film(id: \"ZmlsbXM6MQ==\") {\n" +
                            "id\n" +
                            "title\n" +
                            "episodeID\n" +
                            "director\n" +
                            "openingCrawl\n" +
                        "}\n" +
                    "}\n"
        }
        set { }
    }
}

class FilmThreadUnconfinedRequest: ThreadUnconfinedRequest {
    /*
     query film {
        film(id: "ZmlsbXM6MQ==") {
            title
            episodeID
            director
            openingCrawl
        }
     }
     */
    
    typealias SerializedObject = FilmThreadUnconfined
    
    let query = Operation(type: .query,
                          name: "film",
                          fields: [
                            Object(name: "film",
                                   alias: nil,
                                   fields: [
                                    "id",
                                    Scalar(name: "title", alias: nil),
                                    Scalar(name: "episodeID", alias: nil),
                                    Scalar(name: "director", alias: nil),
                                    Scalar(name: "openingCrawl", alias: nil)],
                                   arguments: ["id" : "ZmlsbXM6MQ=="])
                        ])
    
    var mapping: Binding<FilmThreadUnconfinedMapping> {
        return Binding.mapping("data.film", FilmThreadUnconfinedMapping())
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

class FilmThreadUnconfinedMapping: AnyMapping {
    typealias AdapterKind = AnyAdapterImp<FilmThreadUnconfined>
    
    public func mapping(toMap: inout FilmThreadUnconfined, context: MappingContext) {
        toMap.title         <- ("title", context)
        toMap.episode       <- ("episodeID", context)
        toMap.openingCrawl  <- ("openingCrawl", context)
        toMap.director      <- ("director", context)
    }
}

struct FilmThreadUnconfined: AnyMappable {
    var remoteId: String?
    var title: String?
    var episode: Int?
    var openingCrawl: String?
    var director: String?
}
