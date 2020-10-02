@testable import AutoGraphQL
import Foundation
import JSONValueRX

class FilmSubscriptionRequest: Request {
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
    
    let queryDocument = Operation(type: .subscription,
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
    
    let rootKeyPath: String = "data.film"
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: AutoGraphResult<Film>) throws { }
}
