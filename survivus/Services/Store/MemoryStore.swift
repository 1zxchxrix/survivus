import Foundation
import Combine

final class MemoryStore: ObservableObject {
    @Published var config: SeasonConfig
    @Published var results: [EpisodeResult]
    @Published var users: [UserProfile]
    @Published var seasonPicks: [String: SeasonPicks]
    @Published var weeklyPicks: [String: [Int: WeeklyPicks]]

    init(config: SeasonConfig, results: [EpisodeResult], users: [UserProfile]) {
        self.config = config
        self.results = results
        self.users = users
        self.seasonPicks = Dictionary(uniqueKeysWithValues: users.map { ($0.id, SeasonPicks(userId: $0.id)) })
        self.weeklyPicks = Dictionary(uniqueKeysWithValues: users.map { ($0.id, [:]) })
    }

    var resultsByEpisode: [Int: EpisodeResult] {
        Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
    }

    func picks(for userId: String, episodeId: Int) -> WeeklyPicks {
        if let picks = weeklyPicks[userId]?[episodeId] { return picks }
        let picks = WeeklyPicks(userId: userId, episodeId: episodeId)
        weeklyPicks[userId, default: [:]][episodeId] = picks
        return picks
    }

    func save(_ picks: WeeklyPicks) {
        weeklyPicks[picks.userId, default: [:]][picks.episodeId] = picks
        objectWillChange.send()
    }
}
