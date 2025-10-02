import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // TODO: When a Core Data-backed persistence layer is introduced, inject a persistent store
    // implementation here (likely created from a `PersistenceController`) instead of the
    // in-memory mock `MemoryStore` so user progress survives app restarts.
    @Published var store: MemoryStore
    @Published var currentUserId: String

    init() {
        let config = SeasonConfig.mock()
        let results = config.episodes.map { EpisodeResult.mock(episodeId: $0.id) }
        let users = [UserProfile(id: "u1", displayName: "Zac"), UserProfile(id: "u2", displayName: "Sam")]
        self.store = MemoryStore(config: config, results: results, users: users)
        self.currentUserId = users.first!.id
    }

    var scoring: ScoringEngine {
        ScoringEngine(config: store.config, resultsByEpisode: store.resultsByEpisode)
    }
}
