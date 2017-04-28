import JSONValueRX
import Crust
import Realm
@testable import AutoGraphQL

struct VariableFilm: AnyMappable, ThreadAdaptable {
    let arbitraryScalar = "scalar"
    var allFilms: [Film] = []
    var node: Film? = nil
    
    var threadSafePayload: String {
        return self.arbitraryScalar
    }
    
    // NOTE: If we could use a tuple here instead that would be best. Haven't figured
    // out a simple way to resolve those types though.
    var threadConfinedPayload: [[RLMObject]] {
        let nodePayload = self.node != nil ? [self.node!] : []
        return [nodePayload, self.allFilms]
    }
    
    init() { }
    
    init(threadSafePayload: String, threadConfinedPayload: [[RLMObject]]) {
        self.init()
        self.node = threadConfinedPayload[0].first as? Film
        self.allFilms = threadConfinedPayload[1] as! [Film]
    }
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
    let threadAdapter: NestedThreadAdapter<VariableFilm, RealmThreadAdapter>? = NestedThreadAdapter<VariableFilm, RealmThreadAdapter>(nestedThreadAdapter: RealmThreadAdapter())
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: Result<Film>) throws { }
}

class VariableFilmMapping: AnyMapping {
    typealias MappedObject = VariableFilm
    typealias AdapterKind = AnyAdapterImp<VariableFilm>
    
    public func mapping(toMap: inout VariableFilm, context: MappingContext) {
        toMap.allFilms      <- (.mapping("allFilms.films", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default()))), context)
        toMap.node          <- (.mapping("node", FilmMapping(adapter: RealmAdapter(realm: RLMRealm.default()))), context)
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

protocol ThreadAdaptable {
    associatedtype ThreadSafePayload
    associatedtype ThreadConfinedPayload: RangeReplaceableCollection
    
    var threadSafePayload: ThreadSafePayload { get }
    var threadConfinedPayload: [ThreadConfinedPayload] { get }
    
    init(threadSafePayload: ThreadSafePayload, threadConfinedPayload: [ThreadConfinedPayload])
}

struct NestedThreadAdapter<T: ThreadAdaptable, A: ThreadAdapter>: ThreadAdapter
where A.BaseType == T.ThreadConfinedPayload.Iterator.Element, A.CollectionType == T.ThreadConfinedPayload {
    
    public typealias BaseType = T
    
    let nestedThreadAdapter: A
    
    init(nestedThreadAdapter: A) {
        self.nestedThreadAdapter = nestedThreadAdapter
    }
    
    public func threadSafeRepresentations(`for` objects: [T], ofType type: Any.Type) throws -> [(T.ThreadSafePayload, [[A.ThreadSafeRepresentation]])] {
        return try objects.map { object in
            let threadConfinedPayload = object.threadConfinedPayload
            var safe = Array<[A.ThreadSafeRepresentation]>()    // Type inference is failing here.
            for value in threadConfinedPayload {
                safe.append(try nestedThreadAdapter.threadSafeRepresentations(for: value, ofType: type(of: value)))
            }
            return (object.threadSafePayload, safe)
        }
    }
    
    public func retrieveObjects(`for` representations: [(T.ThreadSafePayload, [[A.ThreadSafeRepresentation]])]) throws -> [T] {
        return try representations.map { payload in
            let threadConfinedPayload = try payload.1.map { try nestedThreadAdapter.retrieveObjects(for: $0) }
            return T(threadSafePayload: payload.0, threadConfinedPayload: threadConfinedPayload)
        }
    }
}
