import Foundation

public struct SubscriptionResponseHandler {
    public typealias WebSocketCompletionBlock = (Result<Data, Error>) -> Void
    
    private let completion: WebSocketCompletionBlock
    
    init(completion: @escaping WebSocketCompletionBlock) {
        self.completion = completion
    }
    
    public func didFinish(subscription: SubscriptionResponsePayload) {
        if let error = subscription.error {
            self.completion(.failure(error))
        }
        else if let data = subscription.payload, subscription.type == "data" {
            self.completion(.success(data))
        }
    }
    
    public func didFinish(error: Error) {
        self.completion(.failure(error))
    }
}
