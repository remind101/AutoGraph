import AutoGraphQL
import Foundation
import JSONValueRX

struct Film: Decodable, Equatable {
    let remoteId: String
    let title: String
    let episode: Int
    let openingCrawl: String
    let director: String
    
    enum CodingKeys: String, CodingKey {
        case remoteId = "id"
        case title
        case episode = "episodeID"
        case openingCrawl
        case director
    }
}
