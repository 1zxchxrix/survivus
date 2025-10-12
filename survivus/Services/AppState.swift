import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // TODO: When a Core Data-backed persistence layer is introduced, inject a persistent store
    // implementation here (likely created from a `PersistenceController`) instead of the
    // in-memory mock `MemoryStore` so user progress survives app restarts.
    @Published var store: MemoryStore {
        didSet {
            guard isStoreObservationActive else { return }
            configureStoreObservation()
        }
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
    private var isStoreObservationActive = false
    private let repository: FirestoreLeagueRepository

    init(
        seasonId: String = FirestoreLeagueRepository.defaultSeasonId,
        repository: FirestoreLeagueRepository? = nil,
        store: MemoryStore? = nil,
        phases: [PickPhase]? = nil,
        connectToFirestore: Bool = true
    ) {
        let initialStore = store ?? MemoryStore.placeholder()
        self.store = initialStore
        self.currentUserId = initialStore.users.first?.id ?? ""
        self.phases = phases ?? []
        self.activatedPhaseIDs = []
        self.activePhaseId = nil
        self.repository = repository ?? FirestoreLeagueRepository(seasonId: seasonId)
        configureStoreObservation()
        isStoreObservationActive = true

        if connectToFirestore {
            configureFirestoreBindings()
        }
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

    private func configureStoreObservation() {
        store.delegate = self
        subscribeToStoreChanges()
    }

    private func configureFirestoreBindings() {
        repository.observeSeasonConfig { [weak self] config in
            self?.store.config = config
        }

        repository.observeSeasonState { [weak self] state in
            guard let self else { return }
            if let activeId = state.activePhaseId.flatMap({ UUID(uuidString: $0) }) {
                self.activePhaseId = activeId
            } else {
                self.activePhaseId = nil
            }
            let activated = state.activatedPhaseIds?.compactMap { UUID(uuidString: $0) } ?? []
            self.activatedPhaseIDs = Set(activated)
        }

        repository.observePhases { [weak self] documents in
            guard let self else { return }
            let pairs: [(PickPhase, Int)] = documents.compactMap { document in
                guard let phaseId = document.phaseId else { return nil }
                let categories = document.categories.compactMap { $0.model() }
                let phase = PickPhase(id: phaseId, name: document.name, categories: categories)
                let sortIndex = document.sortIndex ?? Int.max
                return (phase, sortIndex)
            }
            self.phases = pairs.sorted(by: { $0.1 < $1.1 }).map(\.0)
        }

        repository.observeResults { [weak self] results in
            self?.store.results = results
        }

        repository.observeUsers { [weak self] users in
            guard let self else { return }
            self.store.users = users
            guard !users.isEmpty else {
                self.currentUserId = ""
                return
            }

            if self.currentUserId.isEmpty || !users.contains(where: { $0.id == self.currentUserId }) {
                self.currentUserId = users.first!.id
            }
        }

        repository.observeSeasonPicks { [weak self] picks in
            guard let self else { return }
            let dictionary = Dictionary(uniqueKeysWithValues: picks.map { ($0.userId, $0) })
            self.store.seasonPicks = dictionary
        }

        repository.observeWeeklyPicks { [weak self] picks in
            guard let self else { return }
            var grouped: [String: [Int: WeeklyPicks]] = [:]
            for pick in picks {
                grouped[pick.userId, default: [:]][pick.episodeId] = pick
            }
            self.store.weeklyPicks = grouped
        }
    }
}

extension AppState: MemoryStoreDelegate {
    func memoryStore(_ store: MemoryStore, didSaveWeeklyPicks picks: WeeklyPicks) {
        repository.saveWeeklyPicks(picks)
    }

    func memoryStore(_ store: MemoryStore, didUpdateSeasonPicks picks: SeasonPicks) {
        repository.saveSeasonPicks(picks)
    }
}

#if DEBUG
extension AppState {
    static var preview: AppState {
        let config = SeasonConfig.mock()
        let results = (1...2).map { EpisodeResult.mock(episodeId: $0) }
        let users = [
            UserProfile(id: "u1", displayName: "Zac", avatarAssetName: "zac"),
            UserProfile(id: "u2", displayName: "Sam", avatarAssetName: "mace"),
            UserProfile(id: "u3", displayName: "Chris", avatarAssetName: "chris"),
            UserProfile(id: "u4", displayName: "Liz", avatarAssetName: "liz")
        ]
        let store = MemoryStore(config: config, results: results, users: users)
        store.loadMockPicks()
        return AppState(store: store, phases: PickPhase.preconfigured, connectToFirestore: false)
    }
}
#endif
