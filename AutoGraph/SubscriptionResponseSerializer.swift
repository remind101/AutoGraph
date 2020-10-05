import Foundation
import JSONValueRX

enum SubscriptionResponseSerializerError: Error {
    case failedToConvertTextToData
}

public final class SubscriptionResponseSerializer {
    private let queue = DispatchQueue(label: "org.autograph.subscription_response_handler", qos: .default)
    
    func serialize(data: Data) throws -> SubscriptionResponse {
        return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
    }
    
    func serialize(text: String) throws -> SubscriptionResponse {
        guard let data = text.data(using: .utf8) else {
            throw SubscriptionResponseSerializerError.failedToConvertTextToData
        }
        
        return try self.serialize(data: data)
    }
    
    func serializeFinalObject<SerializedObject: Decodable>(data: Data, completion: @escaping (Result<SerializedObject, Error>) -> Void) {
        self.queue.async {
            do {
                let serializedObject = try JSONDecoder().decode(SerializedObject.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(serializedObject))
                }
            }
            catch let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

public struct SubscriptionResponse: Decodable {
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
    let type: GraphQLWSProtocol?
    let error: AutoGraphError?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id  = try container.decode(String.self, forKey: .id)
        self.type = GraphQLWSProtocol(rawValue: try container.decode(String.self, forKey: .type))
        let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
        self.payload = try payloadContainer.decodeIfPresent(JSONValue.self, forKey: .data)?.encode()
        
        let payloadJSON = try container.decode(JSONValue.self, forKey: .payload)
        self.error = AutoGraphError(graphQLResponseJSON: payloadJSON, response: nil, networkErrorParser: nil)
    }
}
