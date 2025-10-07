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
        let results: [EpisodeResult] = []
        let users = [
            UserProfile(id: "u1", displayName: "Zac", avatarAssetName: "zac"),
            UserProfile(id: "u2", displayName: "Mace", avatarAssetName: "mace"),
            UserProfile(id: "u3", displayName: "Chris", avatarAssetName: "chris"),
            UserProfile(id: "u4", displayName: "Liz", avatarAssetName: "liz")
        ]
        self.store = MemoryStore(config: config, results: results, users: users)
        self.currentUserId = users.first!.id
    }

    var scoring: ScoringEngine {
        ScoringEngine(config: store.config, resultsByEpisode: store.resultsByEpisode)
    }
}
