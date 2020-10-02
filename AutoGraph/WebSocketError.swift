import Foundation

public enum WebSocketError: Error {
    case webSocketNotConnected(String)
    case subscriptionRequestBodyFailed(String)
    case subscriptionPayloadFailedSerialization([String : Any], underlyingError: Error?)
    
    public var localizedDescription: String {
        switch self {
        case let .webSocketNotConnected(subscription):
            return "WebSocket is not open to make subscription: \(subscription)"
        case let .subscriptionRequestBodyFailed(operationName):
            return "Subscription request body failed to serialize for query: \(operationName)"
        case let .subscriptionPayloadFailedSerialization(payload, underlyingError):
            return "Subscription message payload failed to serialize message string: \(payload) underlying error: \(String(describing: underlyingError))"
        }
    }
}
