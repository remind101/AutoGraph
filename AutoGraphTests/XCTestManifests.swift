#if !canImport(ObjectiveC)
import XCTest

extension AlamofireClientTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__AlamofireClientTests = [
        ("testAuthenticatingSetsTokens", testAuthenticatingSetsTokens),
        ("testAuthHandlerDelegateCallsBackWhenAuthenticatingDirectlyIfRefreshing", testAuthHandlerDelegateCallsBackWhenAuthenticatingDirectlyIfRefreshing),
        ("testForwardsSendRequestToAlamofireAndRespectsHeaders", testForwardsSendRequestToAlamofireAndRespectsHeaders),
        ("testSetsAuthHandlerOnSession", testSetsAuthHandlerOnSession),
    ]
}

extension AuthHandlerTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__AuthHandlerTests = [
        ("testAdaptsAuthToken", testAdaptsAuthToken),
        ("testDoesNotGetAuthTokensIfFailure", testDoesNotGetAuthTokensIfFailure),
        ("testGetsAuthTokensIfSuccess", testGetsAuthTokensIfSuccess),
    ]
}

extension AutoGraphTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__AutoGraphTests = [
        ("testArrayObjectSerialization", testArrayObjectSerialization),
        ("testArraySubscription", testArraySubscription),
        ("testAuthHandlerBeganReauthenticationPausesDispatcher", testAuthHandlerBeganReauthenticationPausesDispatcher),
        ("testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher", testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher),
        ("testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll", testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll),
        ("testCancelAllCancelsDispatcherAndClient", testCancelAllCancelsDispatcherAndClient),
        ("testFunctional401Request", testFunctional401Request),
        ("testFunctional401RequestNotHandled", testFunctional401RequestNotHandled),
        ("testFunctionalGlobalLifeCycle", testFunctionalGlobalLifeCycle),
        ("testFunctionalLifeCycle", testFunctionalLifeCycle),
        ("testFunctionalSingleFilmRequest", testFunctionalSingleFilmRequest),
        ("testRequestIncludingNetworking", testRequestIncludingNetworking),
        ("testSubscription", testSubscription),
        ("testTriggeringReauthenticationPausesSystem", testTriggeringReauthenticationPausesSystem),
    ]
}

extension DispatcherTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DispatcherTests = [
        ("testClearsRequestsOnCancel", testClearsRequestsOnCancel),
        ("testFailureReturnsToCaller", testFailureReturnsToCaller),
        ("testForwardsAndClearsPendingRequestsOnUnpause", testForwardsAndClearsPendingRequestsOnUnpause),
        ("testForwardsRequestToSender", testForwardsRequestToSender),
        ("testHoldsRequestsWhenPaused", testHoldsRequestsWhenPaused),
    ]
}

extension ErrorTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ErrorTests = [
        ("testAutoGraphErrorGraphQLErrorUsesMessages", testAutoGraphErrorGraphQLErrorUsesMessages),
        ("testAutoGraphErrorProducesNetworkErrorForNetworkErrorParserMatch", testAutoGraphErrorProducesNetworkErrorForNetworkErrorParserMatch),
        ("testGraphQLErrorUsesMessageForLocalizedDescription", testGraphQLErrorUsesMessageForLocalizedDescription),
        ("testInvalidResponseLocalizedErrorDoesntCrash", testInvalidResponseLocalizedErrorDoesntCrash),
    ]
}

extension ResponseHandlerTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ResponseHandlerTests = [
        ("testErrorsJsonReturnsGraphQLError", testErrorsJsonReturnsGraphQLError),
        ("testMappingErrorReturnsMappingError", testMappingErrorReturnsMappingError),
        ("testNetworkErrorReturnsNetworkError", testNetworkErrorReturnsNetworkError),
        ("testPreMappingHookCalledBeforeMapping", testPreMappingHookCalledBeforeMapping),
        ("testResponseReturnedFromGraphQLError", testResponseReturnedFromGraphQLError),
        ("testResponseReturnedFromInvalidResponseError", testResponseReturnedFromInvalidResponseError),
        ("testResponseReturnedFromMappingError", testResponseReturnedFromMappingError),
        ("testResponseReturnedFromNetworkError", testResponseReturnedFromNetworkError),
    ]
}

extension WebSocketClientTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__WebSocketClientTests = [
        ("testConnectionOccursOnReconnectAttemptTwo", testConnectionOccursOnReconnectAttemptTwo),
        ("testDisconnectEventReconnects", testDisconnectEventReconnects),
        ("testGenerateSubscriptionID", testGenerateSubscriptionID),
        ("testReconnectIsNotCalledIfFullDisconnect", testReconnectIsNotCalledIfFullDisconnect),
        ("testSendSubscriptionCorrectlyDecodesResponse", testSendSubscriptionCorrectlyDecodesResponse),
        ("testSendSubscriptionResponseHandlerIsCalledOnSuccess", testSendSubscriptionResponseHandlerIsCalledOnSuccess),
        ("testSubscribeQueuesAndSendsSubscriptionAfterConnectionFinishes", testSubscribeQueuesAndSendsSubscriptionAfterConnectionFinishes),
        ("testSubscriptionsGetRequeued", testSubscriptionsGetRequeued),
        ("testThreeReconnectAttemptsAndDelayTimeIncreaseEachAttempt", testThreeReconnectAttemptsAndDelayTimeIncreaseEachAttempt),
        ("testUnsubscribeAllRemovesSubscriptions", testUnsubscribeAllRemovesSubscriptions),
        ("testUnsubscribeRemovesSubscriptions", testUnsubscribeRemovesSubscriptions),
        ("testWebSocketClientDelegatDidRecieveError", testWebSocketClientDelegatDidRecieveError),
        ("testWebSocketClientDelegateDidReceiveEventGetsCalled", testWebSocketClientDelegateDidReceiveEventGetsCalled),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AlamofireClientTests.__allTests__AlamofireClientTests),
        testCase(AuthHandlerTests.__allTests__AuthHandlerTests),
        testCase(AutoGraphTests.__allTests__AutoGraphTests),
        testCase(DispatcherTests.__allTests__DispatcherTests),
        testCase(ErrorTests.__allTests__ErrorTests),
        testCase(ResponseHandlerTests.__allTests__ResponseHandlerTests),
        testCase(WebSocketClientTests.__allTests__WebSocketClientTests),
    ]
}
#endif
