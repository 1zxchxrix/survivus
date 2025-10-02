import Foundation

struct WeeklyPicks: Identifiable, Hashable, Codable {
    var id: String { "\(userId)-ep-\(episodeId)" }
    let userId: String
    let episodeId: Int
    var remain: Set<String> = []
    var votedOut: Set<String> = []
    var immunity: Set<String> = []
}

struct SeasonPicks: Identifiable, Hashable, Codable {
    var id: String { "\(userId)-season" }
    let userId: String
    var mergePicks: Set<String> = []
    var finalThreePicks: Set<String> = []
    var winnerPick: String?
}
