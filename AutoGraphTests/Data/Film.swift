import Foundation

struct Film: Codable, Equatable {
    var remoteId: String
    var title: String
    var episode: Int
    var openingCrawl: String
    var director: String
    
    enum CodingKeys: String, CodingKey {
        case remoteId = "id"
        case title
        case episode = "episodeID"
        case openingCrawl
        case director
    }
}
