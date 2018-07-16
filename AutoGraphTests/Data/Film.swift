import Crust
import Foundation

struct Film: AnyMappable, Equatable {
    var remoteId: String
    var title: String
    var episode: Int
    var openingCrawl: String
    var director: String
    
    init() {
        self.remoteId = ""
        self.title = ""
        self.episode = 0
        self.openingCrawl = ""
        self.director = ""
    }
    
    enum Key: String, RawMappingKey {
        case id
        case title
        case episodeID
        case openingCrawl
        case director
    }
    
    struct Mapping: AnyMapping {
        func mapping(toMap: inout Film, payload: MappingPayload<Film.Key>) {
            toMap.remoteId      <- (.id, payload)
            toMap.title         <- (.title, payload)
            toMap.episode       <- (.episodeID, payload)
            toMap.openingCrawl  <- (.openingCrawl, payload)
            toMap.director      <- (.director, payload)
        }
    }
}
