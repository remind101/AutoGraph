@testable import AutoGraphQL
import Foundation
import JSONValueRX

class FilmRequest: Request {
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
    
    let objectRootKeyPath: String = "data.film"
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
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
