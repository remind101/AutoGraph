import Foundation

public enum WebSocketError: Error {
    case webSocketNotConnected(subscriptionPayload: String)
    case subscriptionRequestBodyFailed(operationName: String)
    case subscriptionPayloadFailedSerialization([String : Any], underlyingError: Error?)
    
    public var localizedDescription: String {
        switch self {
        case let .webSocketNotConnected(subscriptionPayload):
            return "WebSocket is not connected, cannot yet make a subscription: \(subscriptionPayload)"
        case let .subscriptionRequestBodyFailed(operationName):
            return "Subscription request body failed to serialize for query: \(operationName)"
        case let .subscriptionPayloadFailedSerialization(payload, underlyingError):
            return "Subscription message payload failed to serialize message string: \(payload) underlying error: \(String(describing: underlyingError))"
        }
    }
}
