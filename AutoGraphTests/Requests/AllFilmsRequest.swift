@testable import AutoGraphQL
import Crust
import Foundation
import JSONValueRX

class AllFilmsRequest: ThreadUnconfinedRequest {

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
    
    typealias SerializedObject = [Film]
    
    let queryDocument = Operation(type: .query,
                                  name: "filmRequest",
                                  selectionSet: [
                                    Object(name: "allFilms",
                                           alias: nil,
                                           arguments: nil,
                                           selectionSet: [
                                            Object(name: "films",
                                                   alias: nil,
                                                   selectionSet: [
                                                    Scalar(name: "title", alias: nil),
                                                    Scalar(name: "episodeID", alias: nil),
                                                    Scalar(name: "openingCrawl", alias: nil),
                                                    Scalar(name: "director", alias: nil)]
                                            )])
                        ])
    
    let variables: [AnyHashable : Any]? = nil
    
    var mapping: Binding<String, Film.Mapping> {
        return .mapping("data.allFilms.films", Film.Mapping())
    }
    
    let mappingKeys = AllKeys<Film.Key>()
    
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
