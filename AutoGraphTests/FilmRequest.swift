import JSONValueRX
import Crust
import Realm
@testable import AutoGraph

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
    
    var mapping: Spec<FilmMapping> {
        return Spec.mapping("data.film", FilmMapping(adaptor: RealmAdaptor(realm: RLMRealm.default())))
    }
}

extension Film: ThreadUnsafe { }

class FilmMapping: RealmMapping, ArraySubMapping {
    public var adaptor: RealmAdaptor
    
    public var primaryKeys: [String : Keypath]? {
        return [ "remoteId" : keyPath + "id" ]
    }
    
    public required init(adaptor: RealmAdaptor) {
        self.adaptor = adaptor
    }
    
    open var keyPath: String { return "" }
    
    public func mapping(tomap: inout Film, context: MappingContext) {
        // TODO: Need to add key path at a global scope...
        tomap.remoteId      <- (keyPath + "id", context)
        tomap.title         <- (keyPath + "title", context)
        tomap.episode       <- (keyPath + "episodeID", context)
        tomap.openingCrawl  <- (keyPath + "openingCrawl", context)
        tomap.director      <- (keyPath + "director", context)
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
