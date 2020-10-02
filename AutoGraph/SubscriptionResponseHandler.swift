import Foundation

public struct SubscriptionResponseHandler {
    public typealias WebSocketCompletionBlock = (Result<Data, Error>) -> Void
    
    private let completion: WebSocketCompletionBlock
    
    init(completion: @escaping WebSocketCompletionBlock) {
        self.completion = completion
    }
    
    public func didReceive(subscriptionResponsePayload: SubscriptionResponsePayload) {
        if let error = subscriptionResponsePayload.error {
            self.completion(.failure(error))
        }
        else if let data = subscriptionResponsePayload.payload, subscriptionResponsePayload.type == "data" {
            self.completion(.success(data))
        }
    }
    
    public func didReceive(error: Error) {
        self.completion(.failure(error))
    }
}
