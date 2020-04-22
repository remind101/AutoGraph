import XCTest
import Alamofire
import JSONValueRX
@testable import AutoGraphQL

public extension AutoGraphQL.Request {
    func willSend() throws { }
    func didFinishRequest(response: HTTPURLResponse?, json: JSONValue) throws { }
    func didFinish(result: AutoGraphResult<SerializedObject>) throws { }
}

class FilmRequestWithLifeCycle: FilmRequest {
    var willSendCalled = false
    override func willSend() throws {
        willSendCalled = true
    }
    
    var didFinishCalled = false
    override func didFinish(result: AutoGraphResult<FilmRequest.SerializedObject>) throws {
        didFinishCalled = true
    }
}

private let kDelay = 0.5

class AutoGraphTests: XCTestCase {
    
    class MockDispatcher: Dispatcher {
        var cancelCalled = false
        override func cancelAll() {
            cancelCalled = true
        }
    }
    
    class MockClient: Client {
        public var sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
        public var authTokens: AuthTokens = ("", "")
        public var authHandler: AuthHandler? = AuthHandler(accessToken: nil, refreshToken: nil)
        public var baseUrl: String = ""

        var cancelCalled = false
        func cancelAll() {
            cancelCalled = true
        }
        
        func sendRequest(url: String, parameters: [String : Any], completion: @escaping (AFDataResponse<Any>) -> ()) { }
    }
    
    var subject: AutoGraph!
    
    override func setUp() {
        super.setUp()
        
        let client = AlamofireClient(baseUrl: AutoGraph.localHost,
                                     session: Session(configuration: MockURLProtocol.sessionConfiguration(), interceptor: AuthHandler()))
        self.subject = AutoGraph(client: client)
    }
    
    override func tearDown() {
        self.subject = nil
        Stub.clearAll()
        
        super.tearDown()
    }
    
    func testFunctionalSingleFilmRequest() {
        let stub = FilmStub()
        stub.registerStub()
        
        var called = false
        self.subject.send(FilmRequest()) { result in
            called = true
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testFunctional401Request() {
        class Film401Stub: FilmStub {
            override var jsonFixtureFile: String? {
                get { return "Film401" }
                set { }
            }
        }
        
        self.subject.networkErrorParser = { gqlError in
            guard gqlError.message == "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}" else {
                return nil
            }
            return MockNetworkError(statusCode: 401, underlyingError: gqlError)
        }
        
        let stub = Film401Stub()
        stub.registerStub()
        
        let request = FilmRequest()
        
        var called = false
        self.subject.send(request) { result in
            called = true
            
            XCTFail()
        }
        
        waitFor(delay: kDelay)
        XCTAssertFalse(called)
        
        XCTAssertTrue(self.subject.dispatcher.paused)
        XCTAssertTrue(self.subject.authHandler!.isRefreshing)
        XCTAssertTrue(( try! self.subject.dispatcher.pendingRequests.first!.queryDocument.graphQLString()) == (try! request.queryDocument.graphQLString()))
    }
    
    func testFunctional401RequestNotHandled() {
        class Film401Stub: FilmStub {
            override var jsonFixtureFile: String? {
                get { return "Film401" }
                set { }
            }
        }
        
        self.subject.networkErrorParser = { gqlError in
            guard gqlError.message == "401 - {\"error\":\"Unauthenticated\",\"error_code\":\"unauthenticated\"}" else {
                return nil
            }
            // Not passing back a 401 status code so won't be registered as an auth error.
            return MockNetworkError(statusCode: -1, underlyingError: gqlError)
        }
        
        let stub = Film401Stub()
        stub.registerStub()
        
        let request = FilmRequest()
        
        var called = false
        self.subject.send(request) { result in
            called = true
            
            guard
                case .failure(let failureError) = result,
                case let error as AutoGraphError = failureError,
                case .network(let baseError, let statusCode, _, let underlying) = error,
                case .some(.graphQL(errors: let underlyingErrors, _)) = underlying,
                case let networkError as NetworkError = baseError,
                networkError.statusCode == -1,
                networkError.underlyingError == underlyingErrors.first,
                networkError.statusCode == statusCode
            else {
                XCTFail()
                return
            }
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
        
        XCTAssertFalse(self.subject.dispatcher.paused)
        XCTAssertFalse(self.subject.authHandler!.isRefreshing)
        XCTAssertEqual(self.subject.dispatcher.pendingRequests.count, 0)
    }
    
    func testFunctionalLifeCycle() {
        let stub = FilmStub()
        stub.registerStub()
        
        let request = FilmRequestWithLifeCycle()
        self.subject.send(request, completion: { _ in })
        
        waitFor(delay: kDelay)
        XCTAssertTrue(request.willSendCalled)
        XCTAssertTrue(request.didFinishCalled)
    }
    
    func testFunctionalGlobalLifeCycle() {
        class GlobalLifeCycleMock: GlobalLifeCycle {
            var willSendCalled = false
            override func willSend<R : AutoGraphQL.Request>(request: R) throws {
                self.willSendCalled = request is FilmRequest
            }
            
            var didFinishCalled = false
            override func didFinish<SerializedObject>(result: AutoGraphResult<SerializedObject>) throws {
                guard case .success(let value) = result else {
                    return
                }
                self.didFinishCalled = value is Film
            }
        }
        
        let lifeCycle = GlobalLifeCycleMock()
        self.subject.lifeCycle = lifeCycle
        
        let stub = FilmStub()
        stub.registerStub()
        
        let request = FilmRequest()
        self.subject.send(request, completion: { _ in })
        
        waitFor(delay: kDelay)
        XCTAssertTrue(lifeCycle.willSendCalled)
        XCTAssertTrue(lifeCycle.didFinishCalled)
    }
    
    func testArrayObjectSerialization() {
        
        class GlobalLifeCycleMock: GlobalLifeCycle {
            var gotArray = false
            override func didFinish<SerializedObject>(result: AutoGraphResult<SerializedObject>) throws {
                guard case .success(let value) = result else {
                    return
                }
                self.gotArray = value is [Film]
            }
        }
        
        let lifeCycle = GlobalLifeCycleMock()
        self.subject.lifeCycle = lifeCycle
        
        let stub = AllFilmsStub()
        stub.registerStub()
        
        let request = AllFilmsRequest()
        self.subject.send(request, completion: { _ in })
        
        waitFor(delay: kDelay)
        XCTAssertTrue(lifeCycle.gotArray)
    }
    
    func testRequestIncludingNetworking() {
        let stub = AllFilmsStub()
        stub.registerStub()
        let request = AllFilmsRequest()
        
        var called = false
        self.subject.send(includingNetworkResponse: request) { result in
            called = true
            guard case .success(let data) = result else {
                XCTFail()
                return
            }
            
            let json = try! JSONValue(object: stub.json)
            XCTAssertEqual(data.json, json[request.rootKeyPath])
            XCTAssertEqual(data.value, [Film(remoteId: "ZmlsbXM6MQ==", title: "A New Hope", episode: 4, openingCrawl: "It is a period of civil war.\r\nRebel spaceships, striking\r\nfrom a hidden base, have won\r\ntheir first victory against\r\nthe evil Galactic Empire.\r\n\r\nDuring the battle, Rebel\r\nspies managed to steal secret\r\nplans to the Empire\'s\r\nultimate weapon, the DEATH\r\nSTAR, an armored space\r\nstation with enough power\r\nto destroy an entire planet.\r\n\r\nPursued by the Empire\'s\r\nsinister agents, Princess\r\nLeia races home aboard her\r\nstarship, custodian of the\r\nstolen plans that can save her\r\npeople and restore\r\nfreedom to the galaxy....", director: "George Lucas"), Film(remoteId: "ZmlsbXM6Mg==", title: "The Empire Strikes Back", episode: 5, openingCrawl: "It is a dark time for the\r\nRebellion. Although the Death\r\nStar has been destroyed,\r\nImperial troops have driven the\r\nRebel forces from their hidden\r\nbase and pursued them across\r\nthe galaxy.\r\n\r\nEvading the dreaded Imperial\r\nStarfleet, a group of freedom\r\nfighters led by Luke Skywalker\r\nhas established a new secret\r\nbase on the remote ice world\r\nof Hoth.\r\n\r\nThe evil lord Darth Vader,\r\nobsessed with finding young\r\nSkywalker, has dispatched\r\nthousands of remote probes into\r\nthe far reaches of space....", director: "Irvin Kershner"), Film(remoteId: "ZmlsbXM6Mw==", title: "Return of the Jedi", episode: 6, openingCrawl: "Luke Skywalker has returned to\r\nhis home planet of Tatooine in\r\nan attempt to rescue his\r\nfriend Han Solo from the\r\nclutches of the vile gangster\r\nJabba the Hutt.\r\n\r\nLittle does Luke know that the\r\nGALACTIC EMPIRE has secretly\r\nbegun construction on a new\r\narmored space station even\r\nmore powerful than the first\r\ndreaded Death Star.\r\n\r\nWhen completed, this ultimate\r\nweapon will spell certain doom\r\nfor the small band of rebels\r\nstruggling to restore freedom\r\nto the galaxy...", director: "Richard Marquand"), Film(remoteId: "ZmlsbXM6NA==", title: "The Phantom Menace", episode: 1, openingCrawl: "Turmoil has engulfed the\r\nGalactic Republic. The taxation\r\nof trade routes to outlying star\r\nsystems is in dispute.\r\n\r\nHoping to resolve the matter\r\nwith a blockade of deadly\r\nbattleships, the greedy Trade\r\nFederation has stopped all\r\nshipping to the small planet\r\nof Naboo.\r\n\r\nWhile the Congress of the\r\nRepublic endlessly debates\r\nthis alarming chain of events,\r\nthe Supreme Chancellor has\r\nsecretly dispatched two Jedi\r\nKnights, the guardians of\r\npeace and justice in the\r\ngalaxy, to settle the conflict....", director: "George Lucas"), Film(remoteId: "ZmlsbXM6NQ==", title: "Attack of the Clones", episode: 2, openingCrawl: "There is unrest in the Galactic\r\nSenate. Several thousand solar\r\nsystems have declared their\r\nintentions to leave the Republic.\r\n\r\nThis separatist movement,\r\nunder the leadership of the\r\nmysterious Count Dooku, has\r\nmade it difficult for the limited\r\nnumber of Jedi Knights to maintain \r\npeace and order in the galaxy.\r\n\r\nSenator Amidala, the former\r\nQueen of Naboo, is returning\r\nto the Galactic Senate to vote\r\non the critical issue of creating\r\nan ARMY OF THE REPUBLIC\r\nto assist the overwhelmed\r\nJedi....", director: "George Lucas"), Film(remoteId: "ZmlsbXM6Ng==", title: "Revenge of the Sith", episode: 3, openingCrawl: "War! The Republic is crumbling\r\nunder attacks by the ruthless\r\nSith Lord, Count Dooku.\r\nThere are heroes on both sides.\r\nEvil is everywhere.\r\n\r\nIn a stunning move, the\r\nfiendish droid leader, General\r\nGrievous, has swept into the\r\nRepublic capital and kidnapped\r\nChancellor Palpatine, leader of\r\nthe Galactic Senate.\r\n\r\nAs the Separatist Droid Army\r\nattempts to flee the besieged\r\ncapital with their valuable\r\nhostage, two Jedi Knights lead a\r\ndesperate mission to rescue the\r\ncaptive Chancellor....", director: "George Lucas")])
            XCTAssertEqual(data.httpResponse?.statusCode, 200)
        }
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    func testCancelAllCancelsDispatcherAndClient() {
        let mockClient = MockClient()
        let mockDispatcher = MockDispatcher(url: "blah", requestSender: mockClient, responseHandler: ResponseHandler())
        self.subject = AutoGraph(client: mockClient, dispatcher: mockDispatcher)
        
        self.subject.cancelAll()
        
        XCTAssertTrue(mockClient.cancelCalled)
        XCTAssertTrue(mockDispatcher.cancelCalled)
    }
    
    func testAuthHandlerBeganReauthenticationPausesDispatcher() {
        XCTAssertFalse(self.subject.dispatcher.paused)
        self.subject.authHandlerBeganReauthentication(AuthHandler(accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
    }
    
    func testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher() {
        self.subject.authHandlerBeganReauthentication(AuthHandler(accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
        self.subject.authHandler(AuthHandler(accessToken: nil, refreshToken: nil), reauthenticatedSuccessfully: true)
        XCTAssertFalse(self.subject.dispatcher.paused)
    }
    
    func testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll() {
        let mockClient = MockClient()
        let mockDispatcher = MockDispatcher(url: "blah", requestSender: mockClient, responseHandler: ResponseHandler())
        self.subject = AutoGraph(client: mockClient, dispatcher: mockDispatcher)
        
        self.subject.authHandlerBeganReauthentication(AuthHandler(accessToken: nil, refreshToken: nil))
        XCTAssertTrue(self.subject.dispatcher.paused)
        self.subject.authHandler(AuthHandler(accessToken: nil, refreshToken: nil), reauthenticatedSuccessfully: false)
        XCTAssertTrue(self.subject.dispatcher.paused)
        
        XCTAssertTrue(mockClient.cancelCalled)
        XCTAssertTrue(mockDispatcher.cancelCalled)
    }
    
    func testTriggeringReauthenticationPausesSystem() {
        self.subject.triggerReauthentication()
        self.waitFor(delay: 0.01)
        XCTAssertTrue(self.subject.dispatcher.paused)
        XCTAssertTrue(self.subject.authHandler!.isRefreshing)
    }
    
    func waitFor(delay: TimeInterval) {
        let expectation = self.expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: delay + 1.0, handler: { error in
            if let error = error {
                print(error)
            }
        })
    }
}
