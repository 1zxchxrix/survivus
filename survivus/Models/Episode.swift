import Foundation

struct Episode: Identifiable, Hashable, Codable {
    let id: Int
    var airDate: Date
    var title: String
    var isMergeEpisode: Bool
}

enum Phase: String, Codable {
    case preMerge
    case postMerge
}

struct EpisodeResult: Identifiable, Hashable, Codable {
    let id: Int
    var immunityWinners: [String]
    var votedOut: [String]
}
