import XCTest
@testable import Starscream
@testable import AutoGraphQL
import JSONValueRX

private let kDelay = 0.5

class WebSocketClientTests: XCTestCase {
    var subject: MockWebSocketClient!
    var webSocket: MockWebSocket!
    
    override func setUp() {
        super.setUp()
        let url = URL(string: "localhost")!
        self.webSocket = MockWebSocket(request: URLRequest(url: url))
        self.subject = try! MockWebSocketClient(url: url, webSocket: self.webSocket)
    }
    
    override func tearDown() {
        self.subject = nil
        self.webSocket = nil
        
        super.tearDown()
    }
    
    func testSendSubscriptionResponseHandlerIsCalledOnSuccess() {
        var called = false
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { result in
            
            guard case .success(_) = result else {
                XCTFail()
                return
            }
            
            called = true
        }))
        
        waitFor(delay: kDelay)
        XCTAssertTrue(called)
    }
    
    
    func testSendSubscriptionCorrectlyDecodesResponse() {
        var film: Film?
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { result in
            
            guard case let .success(data) = result else {
                XCTFail()
                return
            }
            
            film = try! JSONDecoder().decode(Film.self, from: data)
        }))
        
        XCTAssertNotNil(film)
        XCTAssertEqual(film?.remoteId, "ZmlsbXM6MQ==")
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

class MockWebSocketClient: AutoGraphQL.WebSocketClient {
    init(url: URL, webSocket: MockWebSocket) throws {
        try super.init(url: url)
        let request = try AutoGraphQL.WebSocketClient.connectionRequest(url: url)
        self.webSocket = webSocket
        self.webSocket.request = request
        self.webSocket.delegate = self
    }
}

class MockWebSocket: Starscream.WebSocket {
    var subscriptionRequest: String?
    var isConnected = false
    
    override func connect() {
        self.didReceive(event: WebSocketEvent.connected([:]))
        self.isConnected = true
    }
    
    override func disconnect(closeCode: UInt16 = CloseCode.normal.rawValue) {
        self.didReceive(event: WebSocketEvent.disconnected("disconnect", 0))
        self.isConnected = false
    }
    
    override func write(string: String, completion: (() -> ())?) {
        self.subscriptionRequest = string
        self.didReceive(event: WebSocketEvent.text(self.createResponseString()))
    }
    
    override func didReceive(event: WebSocketEvent) {
        self.delegate?.didReceive(event: event, client: self)
    }
    
    func createResponseString() -> String {
        let json: [String: Any] = [
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
        
        return try! String(data: JSONValue(dict: json).encode(), encoding: .utf8)!
    }
}
