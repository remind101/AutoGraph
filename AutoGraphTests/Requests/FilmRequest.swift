@testable import AutoGraphQL
import Crust
import Foundation
import JSONValueRX

class FilmRequest: ThreadUnconfinedRequest {
    /*
     query film {
        film(id: "ZmlsbXM6MQ==") {
            id
            title
            episodeID
            director
            openingCrawl
        }
     }
     */
    
    let queryDocument = Operation(type: .query,
                                  name: "film",
                                  selectionSet: [
                                    Object(name: "film",
                                           alias: nil,
                                           arguments: ["id" : "ZmlsbXM6MQ=="],
                                           selectionSet: [
                                            "id",
                                            Scalar(name: "title", alias: nil),
                                            Scalar(name: "episodeID", alias: nil),
                                            Scalar(name: "director", alias: nil),
                                            Scalar(name: "openingCrawl", alias: nil)])
        ])
    
    let variables: [AnyHashable : Any]? = nil
    
    var mapping: Binding<String, Film.Mapping> {
        return .mapping("data.film", Film.Mapping())
    }
    
    let mappingKeys: SetKeyCollection<Film.Key> = SetKeyCollection([.id, .director, .episodeID, .openingCrawl, .title])
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<(Film, JSONValue)>) throws { }
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
