import Foundation

public struct SubscriptionResponseHandler {
    public typealias WebSocketCompletionBlock = (Result<Data, Error>) -> Void
    
    private let completion: WebSocketCompletionBlock
    
    init(completion: @escaping WebSocketCompletionBlock) {
        self.completion = completion
    }
    
    public func didFinish(subscription: SubscriptionPayload) {
        if let error = subscription.error {
            self.completion(.failure(error))
        }
        else if let data = subscription.data, subscription.type == .data  {
            self.completion(.success(data))
        }
    }
}
