import JSONValueRX
import Crust
import Realm
@testable import AutoGraph

class FilmRequest: Request {
    /*
     "query filmRequest {" +
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
    
    let query = Operation(type: .query,
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
    
    var mapping: AllFilmsMapping {
        let adaptor = RealmArrayAdaptor<Film>(realm: RLMRealm.default())
        return AllFilmsMapping(adaptor: adaptor)
    }
}

class AllFilmsMapping: RealmArrayMapping {
    typealias SubType = Film
    
    public var adaptor: RealmArrayAdaptor<Film>
    
    public required init(adaptor: RealmArrayAdaptor<Film>) {
        self.adaptor = adaptor
    }
    
    public func mapping(tomap: inout [Film], context: MappingContext) {
        let mapping = FilmMapping(adaptor: self.adaptor.realmAdaptor)
        _ = tomap <- (.mapping("data.allFilms.films", mapping), context)
    }
}

class FilmMapping: RealmMapping {
    public var adaptor: RealmAdaptor
    
    public var primaryKeys: [String : Keypath]? {
        return [ "remoteId" : "id" ]
    }
    
    public required init(adaptor: RealmAdaptor) {
        self.adaptor = adaptor
    }
    
    public func mapping(tomap: inout Film, context: MappingContext) {
        
        tomap.remoteId      <- ("id", context)
        tomap.title         <- ("title", context)
        tomap.episode       <- ("episodeID", context)
        tomap.openingCrawl  <- ("openingCrawl", context)
        tomap.director      <- ("director", context)
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
