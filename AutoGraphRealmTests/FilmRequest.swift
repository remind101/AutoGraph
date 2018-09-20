@testable import AutoGraphQL
import Crust
import Foundation
import JSONValueRX
import Realm

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
    
    var mapping: Binding<String, FilmMapping> {
        return Binding.mapping("data.film", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default())))
    }
    
    let mappingKeys: SetKeyCollection<FilmKey> = SetKeyCollection([.director, .episodeID, .openingCrawl, .title])
    
    var threadAdapter: RealmThreadAdapter? {
        return RealmThreadAdapter()
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

enum FilmKey: String, RawMappingKey {
    case title
    case episodeID
    case openingCrawl
    case director
}

class FilmMapping: RealmMapping {
    
    public var adapter: RealmAdapter
    
    public var primaryKeys: [Mapping.PrimaryKeyDescriptor]? {
        return [ ("remoteId", "id", nil) ]
    }
    
    public required init(adapter: RealmAdapter) {
        self.adapter = adapter
    }
    
    public func mapping(toMap: inout Film, payload: MappingPayload<FilmKey>) {
        toMap.title         <- (.title, payload)
        toMap.episode       <- (.episodeID, payload)
        toMap.openingCrawl  <- (.openingCrawl, payload)
        toMap.director      <- (.director, payload)
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
    func didFinish(result: Result<FilmThreadUnconfined>) throws {
    }
    
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
    
    var queryDocument: Document {
        let operation = Operation(type: .query,
                                  name: "film",
                                  selectionSet: [
                                    Selection.fragmentSpread(name: "FilmFrag", directives: nil)
            ])
        
        let filmFrag = FragmentDefinition(name: "FilmFrag", type: "Film", selectionSet: [
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
        
        return Document(operations: [operation], fragments: [filmFrag!])
    }
    
    let variables: [AnyHashable : Any]? = nil
    
    var mapping: Binding<String, FilmThreadUnconfinedMapping> {
        return Binding.mapping("data.film", FilmThreadUnconfinedMapping())
    }
    
    var mappingKeys: SetKeyCollection<FilmKey> = SetKeyCollection([.director, .episodeID, .openingCrawl, .title])
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

class FilmThreadUnconfinedMapping: AnyMapping {
    typealias AdapterKind = AnyAdapterImp<FilmThreadUnconfined>
    
    public func mapping(toMap: inout FilmThreadUnconfined, payload: MappingPayload<FilmKey>) {
        toMap.title         <- (.title, payload)
        toMap.episode       <- (.episodeID, payload)
        toMap.openingCrawl  <- (.openingCrawl, payload)
        toMap.director      <- (.director, payload)
    }
}

struct FilmThreadUnconfined: AnyMappable {
    var remoteId: String?
    var title: String?
    var episode: Int?
    var openingCrawl: String?
    var director: String?
}

class FilmThreadUnconfinedStub: Stub {
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
            return """
            query film {
            ...FilmFrag
            }
            fragment FilmFrag on Film {
            film(id: \"ZmlsbXM6MQ==\") {
            id
            title
            episodeID
            director
            openingCrawl
            }
            }
            """
        }
        set { }
    }
}
