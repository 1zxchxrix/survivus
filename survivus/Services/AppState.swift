import Foundation
import Combine

enum StoragePaths {
    static let bucket = "gs://survivus1514.firebasestorage.app"

    static func userAvatarURL(for asset: String) -> URL? {
        URL(string: "\(bucket)/users/\(asset).png") ??
        URL(string: "\(bucket)/users/\(asset).jpg")
    }

    static func contestantAvatarURL(for asset: String) -> URL? {
        let trimmed = asset.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }

        var relativePath = trimmed
        while relativePath.hasPrefix("/") {
            relativePath.removeFirst()
        }

        if relativePath.hasPrefix("contestants/") {
            relativePath.removeFirst("contestants/".count)
        }

        relativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else { return nil }

        let lastComponent = relativePath.split(separator: "/").last
        let path = "contestants/\(relativePath)"

        if lastComponent?.contains(".") == true {
            return URL(string: "\(bucket)/\(path)")
        }

        let preferredExtensions = ["jpg", "png"]
        for fileExtension in preferredExtensions {
            if let url = URL(string: "\(bucket)/\(path).\(fileExtension)") {
                return url
            }
        }

        return nil
    }
}

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
            synchronizeSeasonStateWithFirestore()
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    private var isStoreObservationActive = false
    private var isApplyingRemoteUpdate = false
    private let repository: FirestoreLeagueRepository
    private var cachedContestantAvatarFingerprints: [Contestant.ID: String] = [:]
    private var cachedUserAvatarFingerprints: [UserProfile.ID: String] = [:]

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
        prefetchContestantAvatars(initialStore.config.contestants)
        prefetchUserAvatars(initialStore.users)
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
            self?.performRemoteUpdate {
                self?.store.config = config
                self?.prefetchContestantAvatars(config.contestants)
            }
        }

        repository.observeSeasonState { [weak self] state in
            guard let self else { return }
            self.performRemoteUpdate {
                if let activeId = state.activePhaseId.flatMap({ UUID(uuidString: $0) }) {
                    self.activePhaseId = activeId
                } else {
                    self.activePhaseId = nil
                }
                let activated = state.activatedPhaseIds?.compactMap { UUID(uuidString: $0) } ?? []
                self.activatedPhaseIDs = Set(activated)
            }
        }

        repository.observePhases { [weak self] documents in
            guard let self else { return }
            self.performRemoteUpdate {
                let pairs: [(PickPhase, Int)] = documents.compactMap { document in
                    guard let phaseId = document.phaseId else { return nil }
                    let categories = document.categories.compactMap { $0.model() }
                    let phase = PickPhase(id: phaseId, name: document.name, categories: categories)
                    let sortIndex = document.sortIndex ?? Int.max
                    return (phase, sortIndex)
                }
                self.phases = pairs.sorted(by: { $0.1 < $1.1 }).map(\.0)
            }
        }

        repository.observeResults { [weak self] results in
            self?.performRemoteUpdate {
                self?.store.results = results
            }
        }

        repository.observeUsers { [weak self] users in
            guard let self else { return }
            self.performRemoteUpdate {
                self.store.users = users
                self.prefetchUserAvatars(users)
                guard !users.isEmpty else {
                    self.currentUserId = ""
                    return
                }

                if self.currentUserId.isEmpty || !users.contains(where: { $0.id == self.currentUserId }) {
                    self.currentUserId = users.first!.id
                }
            }
        }

        repository.observeWeeklyPicks { [weak self] picks in
            guard let self else { return }
            self.performRemoteUpdate {
                var grouped: [String: [Int: WeeklyPicks]] = [:]
                for pick in picks {
                    grouped[pick.userId, default: [:]][pick.episodeId] = pick
                }
                self.store.weeklyPicks = grouped
            }
        }
    }

    private func performRemoteUpdate(_ updates: () -> Void) {
        let wasApplying = isApplyingRemoteUpdate
        isApplyingRemoteUpdate = true
        updates()
        isApplyingRemoteUpdate = wasApplying
    }

    private func synchronizeSeasonStateWithFirestore() {
        guard !isApplyingRemoteUpdate else { return }
        repository.updateSeasonState(activePhaseId: activePhaseId, activatedPhaseIds: activatedPhaseIDs)
    }

    func updateContestants(_ contestants: [Contestant]) {
        let previous = store.config.contestants
        store.config.contestants = contestants
        prefetchContestantAvatars(contestants)
        persistSeasonConfig()

        guard !isApplyingRemoteUpdate else { return }

        let removed = previous.filter { previousContestant in
            !contestants.contains(where: { $0.id == previousContestant.id })
        }
        let urls = removed.compactMap(\.avatarURL)
        repository.deleteContestantAvatars(for: urls)
    }

    func saveEpisodeResult(_ result: EpisodeResult) {
        if let index = store.results.firstIndex(where: { $0.id == result.id }) {
            store.results[index] = result
        } else {
            store.results.append(result)
            store.results.sort(by: { $0.id < $1.id })
        }

        guard !isApplyingRemoteUpdate else { return }
        repository.saveEpisodeResult(result)
    }

    func startNewWeek(activating phase: PickPhase) {
        let nextWeekId = (store.results.map(\.id).max() ?? 0) + 1
        let newResult = EpisodeResult(id: nextWeekId, phaseId: phase.id, immunityWinners: [], votedOut: [])
        store.results.append(newResult)
        store.results.sort(by: { $0.id < $1.id })
        activePhaseId = phase.id

        guard !isApplyingRemoteUpdate else { return }
        repository.saveEpisodeResult(newResult)
    }

    func savePhase(_ phase: PickPhase) {
        if let index = phases.firstIndex(where: { $0.id == phase.id }) {
            phases[index] = phase
        } else {
            phases.append(phase)
        }

        guard !isApplyingRemoteUpdate else { return }
        synchronizePhasesWithFirestore()
    }

    func deletePhase(withId id: PickPhase.ID) {
        phases.removeAll { $0.id == id }
        activatedPhaseIDs.remove(id)
        if activePhaseId == id {
            activePhaseId = nil
        }
        synchronizeSeasonStateWithFirestore()

        guard !isApplyingRemoteUpdate else { return }
        repository.deletePhase(withId: id)
        synchronizePhasesWithFirestore()
    }

    private func synchronizePhasesWithFirestore() {
        let enumerated = phases.enumerated().map { (index, phase) in (phase, index) }
        repository.savePhases(enumerated)
    }

    private func persistSeasonConfig() {
        guard !isApplyingRemoteUpdate else { return }
        repository.saveSeasonConfig(store.config)
    }

    private func prefetchContestantAvatars(_ contestants: [Contestant]) {
        var urls: [URL] = []
        var fingerprints: [Contestant.ID: String] = [:]

        for contestant in contestants {
            let fingerprint = contestant.avatarURL?.absoluteString ?? ""
            fingerprints[contestant.id] = fingerprint

            if let previous = cachedContestantAvatarFingerprints[contestant.id],
               previous != fingerprint {
                if let url = contestant.avatarURL {
                    StorageImageCache.invalidate(url: url)
                } else if let previousURL = URL(string: previous) {
                    StorageImageCache.invalidate(url: previousURL)
                }
            }

            if let url = contestant.avatarURL {
                urls.append(url)
            }
        }

        cachedContestantAvatarFingerprints = fingerprints
        StorageImagePrefetcher.shared.prefetch(urls: urls)
    }

    private func prefetchUserAvatars(_ users: [UserProfile]) {
        var urls: [URL] = []
        var fingerprints: [UserProfile.ID: String] = [:]

        for user in users {
            let fingerprint = user.avatarURL?.absoluteString ?? ""
            fingerprints[user.id] = fingerprint

            if let previous = cachedUserAvatarFingerprints[user.id],
               previous != fingerprint {
                if let url = user.avatarURL {
                    StorageImageCache.invalidate(url: url)
                } else if let previousURL = URL(string: previous) {
                    StorageImageCache.invalidate(url: previousURL)
                }
            }

            if let url = user.avatarURL {
                urls.append(url)
            }
        }

        cachedUserAvatarFingerprints = fingerprints
        StorageImagePrefetcher.shared.prefetch(urls: urls)
    }
}

extension AppState: MemoryStoreDelegate {
    func memoryStore(_ store: MemoryStore, didSaveWeeklyPicks picks: WeeklyPicks) {
        repository.saveWeeklyPicks(picks)
    }
}

#if DEBUG
extension AppState {
    static var preview: AppState {
        let config = SeasonConfig.mock()
        let results = (1...2).map { EpisodeResult.mock(episodeId: $0) }
        let users = [
            UserProfile(
                id: "u1",
                displayName: "Zac",
                avatarURL: URL(string: "gs://survivus1514.firebasestorage.app/users/zac.png")
            ),
            UserProfile(
                id: "u2",
                displayName: "Sam",
                avatarURL: URL(string: "gs://survivus1514.firebasestorage.app/users/mace.png")
            ),
            UserProfile(
                id: "u3",
                displayName: "Chris",
                avatarURL: URL(string: "gs://survivus1514.firebasestorage.app/users/chris.png")
            ),
            UserProfile(
                id: "u4",
                displayName: "Liz",
                avatarURL: URL(string: "gs://survivus1514.firebasestorage.app/users/liz.png")
            )
        ]
        let store = MemoryStore(config: config, results: results, users: users)
        store.loadMockPicks()
        return AppState(store: store, phases: PickPhase.preconfigured, connectToFirestore: false)
    }
}
#endif
