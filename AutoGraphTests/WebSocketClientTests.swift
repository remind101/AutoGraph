import XCTest
@testable import Starscream
@testable import AutoGraphQL
import JSONValueRX

private let kDelay = 0.5

class WebSocketClientTests: XCTestCase {
    var subject: MockWebSocketClient!
    var webSocket: MockWebSocket!
    var webSocketDelegate: MockWebSocketClientDelegate!
    
    override func setUp() {
        super.setUp()
        let url = URL(string: "localhost")!
        self.webSocket = MockWebSocket(request: URLRequest(url: url))
        self.subject = try! MockWebSocketClient(url: url, webSocket: self.webSocket)
        self.webSocketDelegate = MockWebSocketClientDelegate()
        self.subject.delegate = self.webSocketDelegate
    }
    
    override func tearDown() {
        self.subject = nil
        self.webSocket = nil
        self.webSocketDelegate = nil
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
            
            let completion: (Result<Film, Error>) -> Void = { result in
                guard case let .success(serializedObject) = result else {
                    XCTFail()
                    return
                }
                
                film = serializedObject
            }
            
            self.subject.subscriptionSerializer.serializeFinalObject(data: data, completion: completion)
        }))
        
        waitFor(delay: kDelay)
        XCTAssertNotNil(film)
        XCTAssertEqual(film?.remoteId, "ZmlsbXM6MQ==")
    }
    
    func testUnsubscribeRemovesSubscriptions() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        let subscriber = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        XCTAssertTrue(self.subject.subscriptions["film}"]!.contains(where: {$0.key == subscriber }))
        
        try! self.subject.unsubscribe(subscriber: subscriber)
        
        XCTAssertEqual(self.subject.subscriptions.count, 0)
    }
    
    
    func testUnsubscribeAllRemovesSubscriptions() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))

        let request2 = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film1")
        _ = self.subject.subscribe(request: request2, responseHandler: SubscriptionResponseHandler(completion: { _ in }))

        try! self.subject.unsubscribeAll(request: request)

        XCTAssertEqual(self.subject.subscriptions.count, 1)
        
        try! self.subject.unsubscribeAll(request: request2)
        
        XCTAssertEqual(self.subject.subscriptions.count, 0)
    }
    
    func testSubscriptionsGetRequeued() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        let request2 = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film1")
        _ = self.subject.subscribe(request: request2, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        XCTAssertTrue(self.subject.queuedSubscriptions.count == 0)
        self.subject.requeueAllSubscribers()
        
        XCTAssertTrue(self.subject.queuedSubscriptions.count == 2)
        XCTAssertEqual(self.subject.subscriptions.count, 0)
    }
    
    func testDisconnectEventReconnects() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        self.subject.didReceive(event: WebSocketEvent.disconnected("", 0), client: self.webSocket)
        XCTAssertTrue(self.subject.reconnectCalled)
    }
    
    
    func testReconnectIsNotCalledIfFullDisconnect() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        _ = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        self.subject.disconnect()
        
        XCTAssertFalse(self.subject.reconnectCalled)
    }
    
    func testWebSocketClientDelegateDidReceiveEventGetsCalled() {
        self.subject.ignoreConnection = true
        let connectionEvent = WebSocketEvent.connected([:])
        self.subject.didReceive(event: connectionEvent, client: self.webSocket)
        
        XCTAssertEqual(self.webSocketDelegate.event, connectionEvent)
        
        let disconnectEvent = WebSocketEvent.disconnected("stop", 0)
        self.subject.didReceive(event: disconnectEvent, client: self.webSocket)

        XCTAssertEqual(self.webSocketDelegate.event, disconnectEvent)

        let textEvent = WebSocketEvent.text("hello")
        self.subject.didReceive(event: textEvent, client: self.webSocket)

        XCTAssertEqual(self.webSocketDelegate.event, textEvent)
    }
    
    func testWebSocketClientDelegatDidRecieveError() {
        self.subject.didReceive(event: WebSocketEvent.error(TestError()), client: self.webSocket)
        
        XCTAssertNotNil(self.webSocketDelegate.error)
    }
    
    func testSubscribeQueuesAndSendsSubscriptionAfterConnectionFinishes() {
        let request = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        let subscriber = self.subject.subscribe(request: request, responseHandler: SubscriptionResponseHandler(completion: { _ in }))
        
        XCTAssertTrue(self.subject.subscriptions["film}"]!.contains(where: {$0.key == subscriber }))

        let request2 = try! SubscriptionRequest(request: FilmSubscriptionRequest(), operationName: "film")
        var subscriptionNotCalled = true
        let subscriber2 = self.subject.subscribe(request: request2, responseHandler: SubscriptionResponseHandler(completion: { _ in
            subscriptionNotCalled = false
        }))
        
        waitFor(delay: kDelay)
        XCTAssertTrue(subscriptionNotCalled)
        XCTAssertEqual(self.subject.subscriptions.count, 1)
        XCTAssertTrue(self.subject.subscriptions["film}"]!.contains(where: {$0.key == subscriber2 }))
    }
    
    func testThreeReconnectAttemptsAndDelayTimeIncreaseEachAttempt() {
        self.webSocket.enableReconnectLoop = true
        self.subject.didReceive(event: WebSocketEvent.error(TestError()), client: self.webSocket)
        let delayTime1 = self.subject.reconnectTime
        guard case let .seconds(seconds) = delayTime1 else {
            XCTFail()
            return
        }
        
        XCTAssertTrue(self.subject.reconnectCalled)
        XCTAssertEqual(self.subject.attemptReconnectCount, 2)
        XCTAssertEqual(seconds, 10)
        
        waitFor(delay: Double(seconds + 1))
        
        let delayTime2 = self.subject.reconnectTime
        guard case let .seconds(seconds2) = delayTime2 else {
            XCTFail()
            return
        }

        XCTAssertTrue(self.subject.reconnectCalled)
        XCTAssertEqual(self.subject.attemptReconnectCount, 1)
        XCTAssertEqual(seconds2, 20)

        waitFor(delay: Double(seconds2 + 1))
        
        let delayTime3 = self.subject.reconnectTime
        guard case let .seconds(seconds3) = delayTime3 else {
            XCTFail()
            return
        }
        
        XCTAssertTrue(self.subject.reconnectCalled)
        XCTAssertEqual(self.subject.attemptReconnectCount, 0)
        XCTAssertEqual(seconds3, 30)
    }
    
    func testConnectionOccursOnReconnectAttemptTwo() {
        self.subject.didReceive(event: WebSocketEvent.error(TestError()), client: self.webSocket)
        let delayTime1 = self.subject.reconnectTime
        guard case let .seconds(seconds) = delayTime1 else {
            XCTFail()
            return
        }
        
        XCTAssertTrue(self.subject.reconnectCalled)
        XCTAssertEqual(self.subject.attemptReconnectCount, 2)
   
        waitFor(delay: Double(seconds + 1))
        
        XCTAssertTrue(self.webSocket.isConnected)
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

class MockWebSocketClientDelegate: WebSocketClientDelegate {
    var error: Error?
    var event: WebSocketEvent?
    
    func didReceive(error: Error) {
        self.error = error
    }
    
    func didReceive(event: WebSocketEvent) {
        self.event = event
    }
}

class MockWebSocketClient: AutoGraphQL.WebSocketClient {
    var subscriptionPayload: String?
    var reconnectCalled = false
    var reconnectTime: DispatchTimeInterval?
    var ignoreConnection = false
    
    init(url: URL, webSocket: MockWebSocket) throws {
        try super.init(url: url)
        let request = try AutoGraphQL.WebSocketClient.connectionRequest(url: url)
        self.webSocket = webSocket
        self.webSocket.request = request
        self.webSocket.delegate = self
    }
    
    override func sendSubscription(request: SubscriptionRequestSerializable) throws {
        self.subscriptionPayload = try! request.serializedSubscriptionPayload()
        
        guard self.state == .connected else {
            throw WebSocketError.webSocketNotConnected(subscriptionPayload: self.subscriptionPayload!)
        }
        
        self.write(self.subscriptionPayload!)
    }
    
    override func reconnect() -> DispatchTimeInterval? {
        self.reconnectCalled = true
        self.reconnectTime = super.reconnect()
        
        return reconnectTime
    }
    
    override func didConnect() throws {
        if !self.ignoreConnection {
            self.reconnectCalled = false
            try super.didConnect()
        }
    }
}

struct TestError: Error {}

class MockWebSocket: Starscream.WebSocket {
    var subscriptionRequest: String?
    var isConnected = false
    var enableReconnectLoop = false
    
    override func connect() {
        if enableReconnectLoop {
            self.isConnected = false
            self.didReceive(event: WebSocketEvent.error(TestError()))
        }
        else {
             self.isConnected = true
             self.didReceive(event: WebSocketEvent.connected([:]))
        }
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
            "id": "film}",
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

extension WebSocketEvent: Equatable {
    public static func ==(lhs: WebSocketEvent, rhs: WebSocketEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.connected(lhsHeader), .connected(rhsHeader)):
            return lhsHeader == rhsHeader
        case let (.disconnected(lhsReason, lhsCode), .disconnected(rhsReason, rhsCode)):
            return lhsReason == rhsReason && lhsCode == rhsCode
        case let (.text(lhsText), .text(rhsText)):
            return lhsText == rhsText
        default:
            return false
        }
    }
}
