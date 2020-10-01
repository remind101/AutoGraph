import Foundation

public class SubscriptionSerializer {
    func serialize(data: Data) -> SubscriptionPayload {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? GraphQLMap else {
                return SubscriptionPayload()
            }
            
            let id = json[GraphQLWSProtocol.Key.id.rawValue] as? String
            let type = GraphQLWSProtocol.Types(rawValue: json[GraphQLWSProtocol.Key.type.rawValue] as? String ?? "")
            guard let payload = json[GraphQLWSProtocol.Key.payload.rawValue] as? GraphQLMap else {
                return SubscriptionPayload()
            }
            
            guard let objectJson = payload["data"] else {
                return SubscriptionPayload()
            }
            
            let data = try JSONSerialization.data(withJSONObject: objectJson, options:.fragmentsAllowed)
            
            return SubscriptionPayload(id: id, type: type, data: data)
        }
        catch {
            return SubscriptionPayload()
        }
    }
    
    func serialize(text: String) -> SubscriptionPayload {
        guard let data = text.data(using: .utf8) else {
            return SubscriptionPayload()
        }
        
        return self.serialize(data: data)
    }
}

public struct SubscriptionPayload {
    let id: String?
    let data: Data?
    let type: GraphQLWSProtocol.Types?
    let error: Error?
    
    public init(
        id: String? = nil,
        type: GraphQLWSProtocol.Types? = nil,
        data: Data? = nil,
        error: Error? = nil
    )
    {
        self.id = id
        self.type = type
        self.data = data
        self.error = error
    }
}
