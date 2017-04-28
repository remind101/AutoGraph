import JSONValueRX
import Crust
import Realm
@testable import AutoGraphQL

struct VariableFilm: AnyMappable {
    var allFilms: [Film] = []
    var node: Film? = nil
}

class VariableFilmRequest: Request {
    typealias SerializedObject = VariableFilm
    
    /*
     query VariableFilmQuery ($nodeId: ID!, $last: Int) {
        allFilms(last: $last) {
            films {
                id
                title
                episodeID
                director
                openingCrawl
            }
        }
        node(id: $nodeId) {
            ... on Film {
                id
                title
                episodeID
                director
                openingCrawl
            }
        }
     }
     */
    
    static let nodeIdVariable = VariableDefinition<NonNullInputValue<ID>>(name: "nodeId")
    static let lastVariable = VariableDefinition<Int>(name: "last")
    
    let query = Operation(type: .query,
                          name: "VariableFilmQuery",
                          variableDefinitions: [
                            try! nodeIdVariable.typeErase(),
                            try! lastVariable.typeErase()
                        ],
                          fields: [
                            Object(name: "allFilms",
                                   fields: [
                                    Object(name: "films",
                                           fields: [
                                            "id",
                                            "title",
                                            "episodeID",
                                            "openingCrawl",
                                            "director"
                                           ])
                                ],
                                   arguments: [ "last" : lastVariable ]),
                            Object(name: "node",
                                   fields: [
                                    "id",
                                    "title",
                                    "episodeID",
                                    "openingCrawl",
                                    "director"
                                    ],
                                   arguments: [ "id" : nodeIdVariable ])
    ])
    
    /*
     {
        "nodeId": "ZmlsbXM6MQ==",
        "last": 1
     }
    */
    
    let variables: [AnyHashable : Any]? = [
        "nodeId" : "ZmlsbXM6MQ==",
        "last" : 1
    ]
    
    let mapping = Binding.mapping("data", VariableFilmMapping())
    let threadAdapter: RealmThreadAdaptor? = RealmThreadAdaptor()
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

class VariableFilmMapping: AnyMapping {
    typealias MappedObject = VariableFilm
    typealias AdapterKind = AnyAdapterImp<VariableFilm>
    
    public func mapping(toMap: inout VariableFilm, context: MappingContext) {
        toMap.allFilms      <- (.mapping("allFilms.films", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default()))), context)
        toMap.node          <- (.mapping("data.film", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default()))), context)
    }
}

class VariableFilmStub: Stub {
    override var jsonFixtureFile: String? {
        get { return "VariableFilm" }
        set { }
    }
    
    override var urlPath: String? {
        get { return "/graphql" }
        set { }
    }
    
    override var graphQLQuery: String {
        get {
            return "query VariableFilmQuery($nodeId: ID!, $last: Int) {\n" +
                "allFilms(last: $last) {\n" +
                    "films {\n" +
                        "id\n" +
                        "title\n" +
                        "episodeID\n" +
                        "openingCrawl\n" +
                        "director\n" +
                    "}\n" +
                "}\n" +
                "node(id: $nodeId) {\n" +
                    "id\n" +        // Really we should be using an inline fragment "... on Film" here, but we don't support those yet.
                    "title\n" +
                    "episodeID\n" +
                    "openingCrawl\n" +
                    "director\n" +
                "}\n" +
            "}"
        }
        set { }
    }
    
    override var variables: [AnyHashable : Any]? {
        get {
            return [
                "nodeId" : "ZmlsbXM6MQ==",
                "last" : 1
            ]
        }
        set { }
    }
}
