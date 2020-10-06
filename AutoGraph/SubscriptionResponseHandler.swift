import Foundation

public struct SubscriptionResponseHandler {
    public typealias WebSocketCompletionBlock = (Result<Data, Error>) -> Void
    public typealias WebSocketConnectionBlock = (WebSocketClient.State) -> Void
    
    private let completion: WebSocketCompletionBlock
    private let connectionState: WebSocketConnectionBlock
    
    init(connectionState: @escaping WebSocketConnectionBlock, completion: @escaping WebSocketCompletionBlock) {
        self.connectionState = connectionState
        self.completion = completion
    }
    
    public func didReceive(subscriptionResponse: SubscriptionResponse) {
        if let error = subscriptionResponse.error {
            didReceive(error: error)
        }
        else if let data = subscriptionResponse.payload, subscriptionResponse.type == .data {
            self.completion(.success(data))
        }
    }
    
    public func didReceive(error: Error) {
        self.completion(.failure(error))
    }
    
    public func didChangeConnectionState(_ state: WebSocketClient.State) {
        self.connectionState(state)
    }
}
