import Foundation

public struct SubscriptionRequest<R: Request> {
    let operationName: String
    let request: R
    let uuid: String
    
    init(request: R, operationName: String) {
        self.operationName = operationName
        self.request = request
        self.uuid = SubscriptionRequest.generateRequestId(request: request,
                                                          operationName: operationName)
    }
    
    public func subscriptionMessage() throws -> String? {
        let query = try self.request.queryDocument.graphQLString()
        
        var body: GraphQLMap = [
            "operationName": operationName,
            "query": query
        ]
        
        if let variables = try self.request.variables?.graphQLVariablesDictionary() {
            body["variables"] = variables
        }
        
        guard let message = OperationMessage(payload: body, id: self.uuid).rawMessage else {
            throw WebSocketError.messagePayloadFailed(body)
        }

        return message
    }
    
    static func generateRequestId<R: Request>(request: R, operationName: String) -> String {
        let start = "\(operationName):{"
        guard let id = try? request.variables?.graphQLVariablesDictionary().reduce(into: start, { (result, arg1) in
            guard let value = arg1.value as? String, let key = arg1.key as? String else {
                return
            }
            
            result += "\(key) : \(value),"
        }) else {
            return start
        }
        
        return id + "}"
    }
}
