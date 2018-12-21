import XCTest

extension AlamofireClientTests {
    static let __allTests = [
        ("testAuthenticatingSetsTokens", testAuthenticatingSetsTokens),
        ("testAuthHandlerDelegateCallsBackWhenAuthenticatingDirectlyIfRefreshing", testAuthHandlerDelegateCallsBackWhenAuthenticatingDirectlyIfRefreshing),
        ("testForwardsSendRequestToAlamofireAndRespectsHeaders", testForwardsSendRequestToAlamofireAndRespectsHeaders),
        ("testSetsRetrierAndAdapterOnSession", testSetsRetrierAndAdapterOnSession),
        ("testUpdatesRetrierAndAdapterWithNewAuthHandler", testUpdatesRetrierAndAdapterWithNewAuthHandler),
    ]
}

extension AuthHandlerTests {
    static let __allTests = [
        ("testAdaptsAuthToken", testAdaptsAuthToken),
        ("testDoesNotGetAuthTokensIfFailure", testDoesNotGetAuthTokensIfFailure),
        ("testGetsAuthTokensIfSuccess", testGetsAuthTokensIfSuccess),
    ]
}

extension AutoGraphTests {
    static let __allTests = [
        ("testArrayObjectSerialization", testArrayObjectSerialization),
        ("testAuthHandlerBeganReauthenticationPausesDispatcher", testAuthHandlerBeganReauthenticationPausesDispatcher),
        ("testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher", testAuthHandlerReauthenticatedSuccessfullyUnpausesDispatcher),
        ("testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll", testAuthHandlerReauthenticatedUnsuccessfullyCancelsAll),
        ("testCancelAllCancelsDispatcherAndClient", testCancelAllCancelsDispatcherAndClient),
        ("testFunctional401Request", testFunctional401Request),
        ("testFunctional401RequestNotHandled", testFunctional401RequestNotHandled),
        ("testFunctionalGlobalLifeCycle", testFunctionalGlobalLifeCycle),
        ("testFunctionalLifeCycle", testFunctionalLifeCycle),
        ("testFunctionalSingleFilmRequest", testFunctionalSingleFilmRequest),
        ("testTriggeringReauthenticationPausesSystem", testTriggeringReauthenticationPausesSystem),
    ]
}

extension DispatcherTests {
    static let __allTests = [
        ("testClearsRequestsOnCancel", testClearsRequestsOnCancel),
        ("testFailureReturnsToCaller", testFailureReturnsToCaller),
        ("testForwardsAndClearsPendingRequestsOnUnpause", testForwardsAndClearsPendingRequestsOnUnpause),
        ("testForwardsRequestToSender", testForwardsRequestToSender),
        ("testHoldsRequestsWhenPaused", testHoldsRequestsWhenPaused),
    ]
}

extension ErrorTests {
    static let __allTests = [
        ("testAutoGraphErrorGraphQLErrorUsesMessages", testAutoGraphErrorGraphQLErrorUsesMessages),
        ("testAutoGraphErrorProducesNetworkErrorForNetworkErrorParserMatch", testAutoGraphErrorProducesNetworkErrorForNetworkErrorParserMatch),
        ("testGraphQLErrorUsesMessageForLocalizedDescription", testGraphQLErrorUsesMessageForLocalizedDescription),
        ("testInvalidResponseLocalizedErrorDoesntCrash", testInvalidResponseLocalizedErrorDoesntCrash),
    ]
}

extension ResponseHandlerTests {
    static let __allTests = [
        ("testErrorsJsonReturnsGraphQLError", testErrorsJsonReturnsGraphQLError),
        ("testMappingErrorReturnsMappingError", testMappingErrorReturnsMappingError),
        ("testNetworkErrorReturnsNetworkError", testNetworkErrorReturnsNetworkError),
        ("testPreMappingHookCalledBeforeMapping", testPreMappingHookCalledBeforeMapping),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AlamofireClientTests.__allTests),
        testCase(AuthHandlerTests.__allTests),
        testCase(AutoGraphTests.__allTests),
        testCase(DispatcherTests.__allTests),
        testCase(ErrorTests.__allTests),
        testCase(ResponseHandlerTests.__allTests),
    ]
}
#endif
