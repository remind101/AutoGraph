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
                                    Scalar(name: "id", alias: nil),
                                    Scalar(name: "title", alias: nil),
                                    Scalar(name: "episodeID", alias: nil),
                                    Scalar(name: "director", alias: nil),
                                    Scalar(name: "openingCrawl", alias: nil)],
                                   fragments: nil,
                                   arguments: [(key: "id", value: "ZmlsbXM6MQ==")])
                            ],
                          fragments: nil,
                          arguments: nil)
    
    var mapping: Binding<FilmMapping> {
        return Binding.mapping("data.film", FilmMapping(adaptor: RealmAdaptor(realm: RLMRealm.default())))
    }
    
    public func didFinish(result: Result<Film>) throws { }
    public func willSend() throws { }
}

extension RLMObject: ThreadUnsafe {
    public static var primaryKeys: [String] {
        guard let primaryKey = self.primaryKey() else {
            fatalError("Must provide a primary key")
        }
        return [primaryKey]
    }
 }

class FilmMapping: RealmMapping {
    
    public var adaptor: RealmAdaptor
    
    public var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return [ ("remoteId", "id", nil) ]
    }
    
    public required init(adaptor: RealmAdaptor) {
        self.adaptor = adaptor
    }
    
    public func mapping(tomap: inout Film, context: MappingContext) {
        tomap.title         <- ("title", context)
        tomap.episode       <- ("episodeID", context)
        tomap.openingCrawl  <- ("openingCrawl", context)
        tomap.director      <- ("director", context)
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
