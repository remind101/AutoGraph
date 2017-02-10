import JSONValueRX
import Crust
import Realm
@testable import AutoGraph

class AllFilmsRequest: Request {
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
    
    typealias Result = [FilmMapping.MappedObject]
    
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
    
    var mapping: Binding<FilmMapping> {
        return Binding.mapping("data.allFilms.films", FilmMapping(adaptor: RealmAdaptor(realm: RLMRealm.default())))
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
