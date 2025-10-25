import Foundation
import Combine

protocol MemoryStoreDelegate: AnyObject {
    func memoryStore(_ store: MemoryStore, didSaveWeeklyPicks picks: WeeklyPicks)
    func memoryStore(_ store: MemoryStore, didUpdateSeasonPicks picks: SeasonPicks)
}

final class MemoryStore: ObservableObject {
    @Published var config: SeasonConfig
    @Published var results: [EpisodeResult]
    @Published var users: [UserProfile]
    @Published var seasonPicks: [String: SeasonPicks]
    @Published var weeklyPicks: [String: [Int: WeeklyPicks]]

    weak var delegate: MemoryStoreDelegate?

    init(config: SeasonConfig, results: [EpisodeResult], users: [UserProfile]) {
        self.config = config
        self.results = results
        self.users = users
        self.seasonPicks = [:]
        self.weeklyPicks = [:]
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
        delegate?.memoryStore(self, didSaveWeeklyPicks: picks)
    }

    func isWeeklyPicksLocked(for userId: String, episodeId: Int) -> Bool {
        guard let picksByEpisode = weeklyPicks[userId] else { return false }

        let submittedEpisodeIds = picksByEpisode.values
            .filter(\.isSubmitted)
            .map(\.episodeId)

        guard let highestSubmitted = submittedEpisodeIds.max() else { return false }

        return episodeId <= highestSubmitted
    }

    func submitWeeklyPicks(for userId: String, episodeId: Int) {
        let hasSubmittedPreviously = weeklyPicks[userId]?.values.contains { $0.isSubmitted } ?? false

        var picks = weeklyPicks[userId]?[episodeId] ?? WeeklyPicks(userId: userId, episodeId: episodeId)
        guard !picks.isSubmitted else { return }
        picks.isSubmitted = true
        save(picks)

        if !hasSubmittedPreviously {
            lockMergePicks(for: userId)
        }
    }

    func updateSeasonPicks(for userId: String, update: (inout SeasonPicks) -> Void) {
        var picks = seasonPicks[userId] ?? SeasonPicks(userId: userId)
        let originalMergePicks = picks.mergePicks
        let wasLocked = picks.mergePicksLocked

        update(&picks)
        if wasLocked {
            picks.mergePicks = originalMergePicks
        }
        picks.mergePicksLocked = wasLocked || picks.mergePicksLocked

        seasonPicks[userId] = picks
        objectWillChange.send()
        delegate?.memoryStore(self, didUpdateSeasonPicks: picks)
    }

    func lockMergePicks(for userId: String) {
        var picks = seasonPicks[userId] ?? SeasonPicks(userId: userId)
        guard !picks.mergePicksLocked else { return }

        picks.mergePicksLocked = true
        seasonPicks[userId] = picks
        objectWillChange.send()
        delegate?.memoryStore(self, didUpdateSeasonPicks: picks)
    }
}

extension MemoryStore {
    static func placeholder() -> MemoryStore {
        MemoryStore(config: .placeholder, results: [], users: [])
    }
}
