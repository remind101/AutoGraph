import Foundation

public enum WebSocketError: Error {
    case requestCreationFailed(URL)
    case webSocketNotConnected(String)
    case subscriptionRequestBodyFailed(String)
    case messagePayloadFailed(GraphQLMap)
    
    public var localizedDescription: String {
        switch self {
        case let .requestCreationFailed(url):
            return "URLRequest for url: \(url) creation failed for websocket"
        case let .webSocketNotConnected(subscription):
            return "WebSocket is not open to make subscription: \(subscription)"
        case let .subscriptionRequestBodyFailed(operationName):
            return "Subscription request body failed to serialize for query: \(operationName)"
        case let .messagePayloadFailed(playload):
            return "Subscription message payload failed to serialize message string: \(playload)"
        }
    }
}
