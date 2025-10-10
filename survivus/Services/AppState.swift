import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // TODO: When a Core Data-backed persistence layer is introduced, inject a persistent store
    // implementation here (likely created from a `PersistenceController`) instead of the
    // in-memory mock `MemoryStore` so user progress survives app restarts.
    @Published var store: MemoryStore {
        didSet { subscribeToStoreChanges() }
    }
    @Published var currentUserId: String
    @Published var phases: [PickPhase]
    @Published private(set) var activatedPhaseIDs: Set<PickPhase.ID>
    @Published var activePhaseId: PickPhase.ID? {
        didSet {
            if let id = activePhaseId {
                activatedPhaseIDs.insert(id)
            }
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let config = SeasonConfig.mock()
        let results: [EpisodeResult] = []
        let users = [
            UserProfile(id: "u1", displayName: "Zac", avatarAssetName: "zac"),
            UserProfile(id: "u2", displayName: "Sam", avatarAssetName: "mace"),
            UserProfile(id: "u3", displayName: "Chris", avatarAssetName: "chris"),
            UserProfile(id: "u4", displayName: "Liz", avatarAssetName: "liz")
        ]
        self.store = MemoryStore(config: config, results: results, users: users)
        self.currentUserId = users.first!.id
        self.phases = PickPhase.preconfigured
        self.activatedPhaseIDs = []
        self.activePhaseId = phases.first?.id
        if let id = activePhaseId {
            activatedPhaseIDs.insert(id)
        }
        subscribeToStoreChanges()
    }

    func selectUser(with userId: String) {
        guard store.users.contains(where: { $0.id == userId }) else { return }
        currentUserId = userId
    }

    var scoring: ScoringEngine {
        ScoringEngine(config: store.config, resultsByEpisode: store.resultsByEpisode)
    }

    var votedOutContestantIDs: Set<String> {
        Set(store.results.flatMap(\.votedOut))
    }

    var activePhase: PickPhase? {
        guard let activePhaseId else { return nil }
        return phases.first(where: { $0.id == activePhaseId })
    }

    func hasPhaseEverBeenActive(_ id: PickPhase.ID) -> Bool {
        activatedPhaseIDs.contains(id)
    }

    private func subscribeToStoreChanges() {
        cancellables.removeAll()

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
