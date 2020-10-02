import Foundation
import JSONValueRX

enum SubscriptionSerializationError: Error {
    case unableToConvertTextToData
}

public class SubscriptionSerializer {
    func serialize(data: Data) throws -> SubscriptionResponsePayload {
        return try JSONDecoder().decode(SubscriptionResponsePayload.self, from: data)
    }
    
    func serialize(text: String) throws -> SubscriptionResponsePayload {
        guard let data = text.data(using: .utf8) else {
            throw SubscriptionSerializationError.unableToConvertTextToData
        }
        
        return try self.serialize(data: data)
    }
}

public struct SubscriptionResponsePayload: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case payload
        case type
    }
    
    enum PayloadCodingKeys: String, CodingKey {
        case data
        case errors
    }
    
    let id: String
    let payload: Data?
    let type: String
    let error: AutoGraphError?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id  = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
        self.payload = try payloadContainer.decodeIfPresent(Data.self, forKey: .data)
        
        let payloadJSON = try container.decode(JSONValue.self, forKey: .payload)
        
        self.error = {
            return AutoGraphError(graphQLResponseJSON: payloadJSON, response: nil, networkErrorParser: nil)
        }()
    }
}
