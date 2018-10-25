@testable import AutoGraphQL
import Foundation
import JSONValueRX

class AllFilmsRequest: Request {
    /*
     query allFilms {
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
                                  name: "allFilms",
                                  selectionSet: [
                                    Object(name: "allFilms",
                                           arguments: nil,
                                           selectionSet: [
                                            Object(name: "films",
                                                   alias: nil,
                                                   arguments: nil,
                                                   selectionSet: [
                                                    "id",
                                                    Scalar(name: "title", alias: nil),
                                                    Scalar(name: "episodeID", alias: nil),
                                                    Scalar(name: "director", alias: nil),
                                                    Scalar(name: "openingCrawl", alias: nil)])
                                        ])
        ])
    
    let variables: [AnyHashable : Any]? = nil
    
    let rootKeyPath: String = "data.allFilms.films"
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<[Film]>) throws { }
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
            return "query allFilms {\n" +
                        "allFilms {\n" +
                            "films {\n" +
                                "id\n" +
                                "title\n" +
                                "episodeID\n" +
                                "director\n" +
                                "openingCrawl\n" +
                            "}\n" +
                        "}\n" +
                    "}\n"
            
        }
        set { }
    }
}
