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
    
    let operationName: String
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
    
    init(operationName: String = "film") {
        self.operationName = operationName
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: AutoGraphResult<Film>) throws { }
    
    static let jsonResponse: [String: Any] = [
        "type": "data",
        "id": "film",
        "payload": [
            "data": [
                "id": "ZmlsbXM6MQ==",
                "title": "A New Hope",
                "episodeID": 4,
                "director": "George Lucas",
                "openingCrawl": "It is a period of civil war.\r\nRebel spaceships, striking\r\nfrom a hidden base, have won\r\ntheir first victory against\r\nthe evil Galactic Empire.\r\n\r\nDuring the battle, Rebel\r\nspies managed to steal secret\r\nplans to the Empire's\r\nultimate weapon, the DEATH\r\nSTAR, an armored space\r\nstation with enough power\r\nto destroy an entire planet.\r\n\r\nPursued by the Empire's\r\nsinister agents, Princess\r\nLeia races home aboard her\r\nstarship, custodian of the\r\nstolen plans that can save her\r\npeople and restore\r\nfreedom to the galaxy...."
            ]
        ]
    ]
}

class FilmSubscriptionRequestWithVariables: Request {
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
    
    let variables: [AnyHashable : Any]? = [
        "id": "ZmlsbXM6MQ=="
    ]
    
    let rootKeyPath: String = "data.film"
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: AutoGraphResult<Film>) throws { }
    
    static let jsonResponse: [String: Any] = [
        "type": "data",
        "id": "film",
        "payload": [
            "data": [
                "id": "ZmlsbXM6MQ==",
                "title": "A New Hope",
                "episodeID": 4,
                "director": "George Lucas",
                "openingCrawl": "It is a period of civil war.\r\nRebel spaceships, striking\r\nfrom a hidden base, have won\r\ntheir first victory against\r\nthe evil Galactic Empire.\r\n\r\nDuring the battle, Rebel\r\nspies managed to steal secret\r\nplans to the Empire's\r\nultimate weapon, the DEATH\r\nSTAR, an armored space\r\nstation with enough power\r\nto destroy an entire planet.\r\n\r\nPursued by the Empire's\r\nsinister agents, Princess\r\nLeia races home aboard her\r\nstarship, custodian of the\r\nstolen plans that can save her\r\npeople and restore\r\nfreedom to the galaxy...."
            ]
        ]
    ]
}

class AllFilmsSubscriptionRequest: Request {
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
    
    let queryDocument = Operation(type: .subscription,
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
    
    // TODO: this isn't even used on subscriptions. consider moving this into an extensive protocol and out of Request.
    let rootKeyPath: String = "data.allFilms"
    
    struct Data: Decodable {
        struct AllFilms: Decodable {
            let films: [Film]
        }
        let allFilms: AllFilms
    }
    
    public func willSend() throws { }
    public func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    public func didFinish(result: AutoGraphResult<Data>) throws { }
    
    static let jsonResponse: [String : Any] = [
        "type": "data",
        "id": "allFilms",
        "payload": [
            "data": [
                "allFilms": [
                    "films": [
                              [
                              "id": "ZmlsbXM6MQ==",
                              "title": "A New Hope",
                              "episodeID": 4,
                              "openingCrawl": "It is a period of civil war.\r\nRebel spaceships, striking\r\nfrom a hidden base, have won\r\ntheir first victory against\r\nthe evil Galactic Empire.\r\n\r\nDuring the battle, Rebel\r\nspies managed to steal secret\r\nplans to the Empire's\r\nultimate weapon, the DEATH\r\nSTAR, an armored space\r\nstation with enough power\r\nto destroy an entire planet.\r\n\r\nPursued by the Empire's\r\nsinister agents, Princess\r\nLeia races home aboard her\r\nstarship, custodian of the\r\nstolen plans that can save her\r\npeople and restore\r\nfreedom to the galaxy....",
                              "director": "George Lucas"
                              ],
                              [
                              "id": "ZmlsbXM6Mg==",
                              "title": "The Empire Strikes Back",
                              "episodeID": 5,
                              "openingCrawl": "It is a dark time for the\r\nRebellion. Although the Death\r\nStar has been destroyed,\r\nImperial troops have driven the\r\nRebel forces from their hidden\r\nbase and pursued them across\r\nthe galaxy.\r\n\r\nEvading the dreaded Imperial\r\nStarfleet, a group of freedom\r\nfighters led by Luke Skywalker\r\nhas established a new secret\r\nbase on the remote ice world\r\nof Hoth.\r\n\r\nThe evil lord Darth Vader,\r\nobsessed with finding young\r\nSkywalker, has dispatched\r\nthousands of remote probes into\r\nthe far reaches of space....",
                              "director": "Irvin Kershner"
                              ],
                              [
                              "id": "ZmlsbXM6Mw==",
                              "title": "Return of the Jedi",
                              "episodeID": 6,
                              "openingCrawl": "Luke Skywalker has returned to\r\nhis home planet of Tatooine in\r\nan attempt to rescue his\r\nfriend Han Solo from the\r\nclutches of the vile gangster\r\nJabba the Hutt.\r\n\r\nLittle does Luke know that the\r\nGALACTIC EMPIRE has secretly\r\nbegun construction on a new\r\narmored space station even\r\nmore powerful than the first\r\ndreaded Death Star.\r\n\r\nWhen completed, this ultimate\r\nweapon will spell certain doom\r\nfor the small band of rebels\r\nstruggling to restore freedom\r\nto the galaxy...",
                              "director": "Richard Marquand"
                              ],
                              [
                              "id": "ZmlsbXM6NA==",
                              "title": "The Phantom Menace",
                              "episodeID": 1,
                              "openingCrawl": "Turmoil has engulfed the\r\nGalactic Republic. The taxation\r\nof trade routes to outlying star\r\nsystems is in dispute.\r\n\r\nHoping to resolve the matter\r\nwith a blockade of deadly\r\nbattleships, the greedy Trade\r\nFederation has stopped all\r\nshipping to the small planet\r\nof Naboo.\r\n\r\nWhile the Congress of the\r\nRepublic endlessly debates\r\nthis alarming chain of events,\r\nthe Supreme Chancellor has\r\nsecretly dispatched two Jedi\r\nKnights, the guardians of\r\npeace and justice in the\r\ngalaxy, to settle the conflict....",
                              "director": "George Lucas"
                              ],
                              [
                              "id": "ZmlsbXM6NQ==",
                              "title": "Attack of the Clones",
                              "episodeID": 2,
                              "openingCrawl": "There is unrest in the Galactic\r\nSenate. Several thousand solar\r\nsystems have declared their\r\nintentions to leave the Republic.\r\n\r\nThis separatist movement,\r\nunder the leadership of the\r\nmysterious Count Dooku, has\r\nmade it difficult for the limited\r\nnumber of Jedi Knights to maintain \r\npeace and order in the galaxy.\r\n\r\nSenator Amidala, the former\r\nQueen of Naboo, is returning\r\nto the Galactic Senate to vote\r\non the critical issue of creating\r\nan ARMY OF THE REPUBLIC\r\nto assist the overwhelmed\r\nJedi....",
                              "director": "George Lucas"
                              ],
                              [
                              "id": "ZmlsbXM6Ng==",
                              "title": "Revenge of the Sith",
                              "episodeID": 3,
                              "openingCrawl": "War! The Republic is crumbling\r\nunder attacks by the ruthless\r\nSith Lord, Count Dooku.\r\nThere are heroes on both sides.\r\nEvil is everywhere.\r\n\r\nIn a stunning move, the\r\nfiendish droid leader, General\r\nGrievous, has swept into the\r\nRepublic capital and kidnapped\r\nChancellor Palpatine, leader of\r\nthe Galactic Senate.\r\n\r\nAs the Separatist Droid Army\r\nattempts to flee the besieged\r\ncapital with their valuable\r\nhostage, two Jedi Knights lead a\r\ndesperate mission to rescue the\r\ncaptive Chancellor....",
                              "director": "George Lucas"
                              ]
                        ]
                ]
            ]
        ]
    ]

}
