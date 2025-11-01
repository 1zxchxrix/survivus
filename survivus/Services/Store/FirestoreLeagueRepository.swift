import Foundation

#if canImport(FirebaseFirestore) && canImport(FirebaseFirestoreInternalWrapper)
import FirebaseFirestore
import FirebaseFirestoreSwift
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

final class FirestoreLeagueRepository {
    static let defaultSeasonId = "season-001"

    private let database: Firestore
    private let seasonId: String
    private var listeners: [ListenerRegistration] = []

    init(seasonId: String = FirestoreLeagueRepository.defaultSeasonId, database: Firestore = Firestore.firestore()) {
        self.seasonId = seasonId
        self.database = database
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Reads

    func observeSeasonConfig(onChange: @escaping @MainActor (SeasonConfig) -> Void) {
        let reference = database.collection("seasons").document(seasonId)
        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "SeasonConfig")
                return
            }
            guard let snapshot, snapshot.exists else { return }
            do {
                let config = try snapshot.data(as: SeasonConfig.self)
                Task { @MainActor in onChange(config) }
            } catch {
                self.logDecodingError(error, context: "SeasonConfig")
            }
        })
    }

    func observeSeasonState(onChange: @escaping @MainActor (SeasonStateDocument) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("state")
            .document("current")

        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "SeasonState")
                return
            }
            do {
                if let snapshot, snapshot.exists {
                    let state = try snapshot.data(as: SeasonStateDocument.self)
                    Task { @MainActor in onChange(state) }
                } else {
                    Task { @MainActor in onChange(SeasonStateDocument()) }
                }
            } catch {
                self.logDecodingError(error, context: "SeasonState")
            }
        })
    }

    func observePhases(onChange: @escaping @MainActor ([PhaseDocument]) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("phases")

        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "Phases")
                return
            }
            guard let documents = snapshot?.documents else { return }
            let phases: [PhaseDocument] = documents.compactMap { document in
                do {
                    return try document.data(as: PhaseDocument.self)
                } catch {
                    self.logDecodingError(error, context: "PhaseDocument")
                    return nil
                }
            }
            Task { @MainActor in onChange(phases) }
        })
    }

    func observeResults(onChange: @escaping @MainActor ([EpisodeResult]) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("results")

        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "Results")
                return
            }
            guard let documents = snapshot?.documents else { return }
            let results: [EpisodeResult] = documents.compactMap { document in
                do {
                    let payload = try document.data(as: EpisodeResultDocument.self)
                    return payload.model
                } catch {
                    self.logDecodingError(error, context: "EpisodeResultDocument")
                    return nil
                }
            }
            Task { @MainActor in
                let sorted = results.sorted(by: { $0.id < $1.id })
                onChange(sorted)
            }
        })
    }

    func observeUsers(onChange: @escaping @MainActor ([UserProfile]) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("users")

        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "Users")
                return
            }
            guard let documents = snapshot?.documents else { return }
            let users: [UserProfile] = documents.compactMap { document in
                do {
                    let payload = try document.data(as: UserDocument.self)
                    return payload.model   // <- UserDocument.model now sets avatarURL
                } catch {
                    self.logDecodingError(error, context: "UserDocument")
                    return nil
                }
            }

            // 🟡 Add this debug block here
            #if DEBUG
            for u in users {
                if let url = u.avatarURL {
                    print("[Users] \(u.displayName) avatar → \(url.absoluteString)")
                } else {
                    print("[Users] \(u.displayName) has no avatarURL")
                }
            }
            #endif

            Task { @MainActor in
                onChange(users.sorted(by: { $0.displayName < $1.displayName }))
            }
        })
    }

    func observeWeeklyPicks(onChange: @escaping @MainActor ([WeeklyPicks]) -> Void) {
        let reference = database
            .collectionGroup("episodes")

        register(reference.addSnapshotListener { snapshot, error in
            if let error {
                self.logSnapshotError(error, context: "WeeklyPicks")
                return
            }
            guard let documents = snapshot?.documents else { return }
            let picks: [WeeklyPicks] = documents.compactMap { document in
                let episodeCollection = document.reference.parent
                let userDocument = episodeCollection.parent
                let weeklyPicksCollection = userDocument?.parent
                let seasonDocument = weeklyPicksCollection?.parent

                guard
                    weeklyPicksCollection?.collectionID == "weeklyPicks",
                    seasonDocument?.documentID == self.seasonId,
                    let userId = userDocument?.documentID
                else {
                    return nil
                }
                do {
                    let payload = try document.data(as: WeeklyPicksDocument.self)
                    return payload.model(userId: userId)
                } catch {
                    self.logDecodingError(error, context: "WeeklyPicksDocument")
                    return nil
                }
            }
            Task { @MainActor in onChange(picks) }
        })
    }

    // MARK: - Writes

    func saveSeasonConfig(_ config: SeasonConfig) {
        let reference = database.collection("seasons").document(seasonId)

        do {
            try reference.setData(from: config, merge: true)
        } catch {
            logEncodingError(error, context: "SeasonConfig")
        }
    }

    func saveEpisodeResult(_ result: EpisodeResult) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("results")
            .document(String(result.id))

        let payload = EpisodeResultDocument(from: result)

        do {
            try reference.setData(from: payload, merge: true)
        } catch {
            logEncodingError(error, context: "EpisodeResult")
        }
    }

    func updateSeasonState(activePhaseId: PickPhase.ID?, activatedPhaseIds: Set<PickPhase.ID>) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("state")
            .document("current")

        let payload = SeasonStateDocument(activePhaseId: activePhaseId, activatedPhaseIds: activatedPhaseIds)

        do {
            try reference.setData(from: payload, merge: true)
        } catch {
            logEncodingError(error, context: "SeasonState")
        }
    }

    func savePhases(_ phases: [(PickPhase, Int)]) {
        let collection = database
            .collection("seasons")
            .document(seasonId)
            .collection("phases")

        for (phase, sortIndex) in phases {
            let reference = collection.document(phase.id.uuidString)
            let payload = PhaseDocument(from: phase, sortIndex: sortIndex)

            do {
                try reference.setData(from: payload, merge: true)
            } catch {
                logEncodingError(error, context: "PhaseDocument")
            }
        }
    }

    func deletePhase(withId id: PickPhase.ID) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("phases")
            .document(id.uuidString)

        reference.delete { error in
            if let error {
                self.logSnapshotError(error, context: "DeletePhase")
            }
        }
    }

    func saveWeeklyPicks(_ picks: WeeklyPicks) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("weeklyPicks")
            .document(picks.userId)
            .collection("episodes")
            .document(String(picks.episodeId))

        let payload = WeeklyPicksDocument(from: picks, seasonId: seasonId)
        do {
            try reference.setData(from: payload, merge: true)
        } catch {
            logEncodingError(error, context: "WeeklyPicks")
        }
    }

    func deleteContestantAvatars(for urls: [URL]) {
#if canImport(FirebaseStorage)
        guard !urls.isEmpty else { return }

        let storage = Storage.storage(url: StoragePaths.bucket)
        for url in urls {
            let reference = storage.reference(forURL: url.absoluteString)
            reference.delete { error in
                if let error {
                    self.logSnapshotError(error, context: "DeleteContestantAvatar")
                }
            }
        }
#endif
    }

    // MARK: - Helpers

    @discardableResult
    private func register(_ listener: ListenerRegistration?) -> ListenerRegistration? {
        guard let listener else { return nil }
        listeners.append(listener)
        return listener
    }

    private func logDecodingError(_ error: Error, context: String) {
        #if DEBUG
        print("[FirestoreLeagueRepository] Failed to decode \(context): \(error)")
        #endif
    }

    private func logEncodingError(_ error: Error, context: String) {
        #if DEBUG
        print("[FirestoreLeagueRepository] Failed to encode \(context): \(error)")
        #endif
    }

    private func logSnapshotError(_ error: Error, context: String) {
        #if DEBUG
        print("[FirestoreLeagueRepository] Firestore returned an error for \(context): \(error)")
        #endif
    }
}

// MARK: - Firestore payloads

struct SeasonStateDocument: Codable {
    var activePhaseId: String?
    var activatedPhaseIds: [String]?

    init() {
        self.activePhaseId = nil
        self.activatedPhaseIds = nil
    }

    init(activePhaseId: PickPhase.ID?, activatedPhaseIds: Set<PickPhase.ID>) {
        self.activePhaseId = activePhaseId?.uuidString
        self.activatedPhaseIds = activatedPhaseIds.isEmpty ? nil : activatedPhaseIds.map(\.uuidString)
    }

    init(activePhaseId: String?, activatedPhaseIds: [String]?) {
        self.activePhaseId = activePhaseId
        self.activatedPhaseIds = activatedPhaseIds
    }
}

struct PhaseDocument: Codable {
    @DocumentID var documentId: String?
    var id: String?
    var name: String
    var sortIndex: Int?
    var categories: [PhaseCategoryDocument]

    var phaseId: UUID? {
        if let id, let uuid = UUID(uuidString: id) {
            return uuid
        }
        if let documentId, let uuid = UUID(uuidString: documentId) {
            return uuid
        }
        return nil
    }

    init(id: String? = nil, name: String, sortIndex: Int? = nil, categories: [PhaseCategoryDocument]) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.categories = categories
    }

    init(from phase: PickPhase, sortIndex: Int) {
        self.init(
            id: phase.id.uuidString,
            name: phase.name,
            sortIndex: sortIndex,
            categories: phase.categories.map(PhaseCategoryDocument.init)
        )
    }
}

struct PhaseCategoryDocument: Codable {
    var id: String
    var name: String
    var columnId: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var wagerPoints: Int?
    var autoScoresRemainingContestants: Bool = false
    var isLocked: Bool
    var usesWager: Bool?

    init(
        id: String,
        name: String,
        columnId: String,
        totalPicks: Int,
        pointsPerCorrectPick: Int?,
        wagerPoints: Int?,
        autoScoresRemainingContestants: Bool = false,
        isLocked: Bool,
        usesWager: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.columnId = columnId
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.wagerPoints = wagerPoints
        self.autoScoresRemainingContestants = autoScoresRemainingContestants
        self.isLocked = isLocked
        self.usesWager = usesWager
    }

    init(from category: PickPhase.Category) {
        self.init(
            id: category.id.uuidString,
            name: category.name,
            columnId: category.columnId,
            totalPicks: category.totalPicks,
            pointsPerCorrectPick: category.pointsPerCorrectPick,
            wagerPoints: category.wagerPoints,
            autoScoresRemainingContestants: category.autoScoresRemainingContestants,
            isLocked: category.isLocked,
            usesWager: category.usesWager
        )
    }

    func model() -> PickPhase.Category? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let shouldUseWager = usesWager ?? (wagerPoints != nil)
        return PickPhase.Category(
            id: uuid,
            name: name,
            columnId: columnId,
            totalPicks: totalPicks,
            pointsPerCorrectPick: pointsPerCorrectPick,
            wagerPoints: wagerPoints,
            autoScoresRemainingContestants: autoScoresRemainingContestants,
            isLocked: isLocked,
            usesWager: shouldUseWager
        )
    }
}

struct EpisodeResultDocument: Codable {
    @DocumentID var documentId: String?
    var phaseId: String?
    var immunityWinners: [String]
    var votedOut: [String]
    var categoryWinners: [String: [String]]?

    init(
        documentId: String? = nil,
        phaseId: String? = nil,
        immunityWinners: [String],
        votedOut: [String],
        categoryWinners: [String: [String]]? = nil
    ) {
        self.documentId = documentId
        self.phaseId = phaseId
        self.immunityWinners = immunityWinners
        self.votedOut = votedOut
        self.categoryWinners = categoryWinners
    }

    init(from result: EpisodeResult) {
        let encodedCategories = result.categoryWinners.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = entry.value
        }

        self.init(
            documentId: String(result.id),
            phaseId: result.phaseId?.uuidString,
            immunityWinners: result.immunityWinners,
            votedOut: result.votedOut,
            categoryWinners: encodedCategories.isEmpty ? nil : encodedCategories
        )
    }

    var model: EpisodeResult? {
        guard let documentId, let id = Int(documentId) else { return nil }
        var result = EpisodeResult(id: id, phaseId: phaseId.flatMap(UUID.init), immunityWinners: immunityWinners, votedOut: votedOut)
        categoryWinners?.forEach { key, values in
            if let uuid = UUID(uuidString: key) {
                result.setWinners(values, for: uuid)
            }
        }
        return result
    }
}

struct UserDocument: Codable {
    @DocumentID var documentId: String?
    var displayName: String
    var avatarAssetName: String?
    var avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case documentId
        case displayName
        case avatarAssetName
        case avatarURL
    }

    var model: UserProfile? {
        guard let documentId else { return nil }

        // Build avatar URL from asset name if Firestore didn't store a full URL
        let resolvedURL: URL? = {
            if let explicit = avatarURL { return explicit }
            if let asset = avatarAssetName, !asset.isEmpty {
                return StoragePaths.userAvatarURL(for: asset)
            }
            return nil
        }()

        return UserProfile(
            id: documentId,
            displayName: displayName,
            avatarAssetName: avatarAssetName,
            avatarURL: resolvedURL
        )
    }

}

struct WeeklyPicksDocument: Codable {
    @DocumentID var documentId: String?
    var seasonId: String?
    var categorySelections: [String: [String]]?
    var categoryWagers: [String: Int]?
    var isSubmitted: Bool?

    init() {}

    init(from picks: WeeklyPicks, seasonId: String) {
        self.seasonId = seasonId
        let encodedSelections = picks.categorySelections.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = Array(entry.value)
        }
        categorySelections = encodedSelections.isEmpty ? nil : encodedSelections
        let encodedWagers = picks.categoryWagers.reduce(into: [String: Int]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = entry.value
        }
        categoryWagers = encodedWagers.isEmpty ? nil : encodedWagers
        isSubmitted = picks.isSubmitted
    }

    func model(userId: String) -> WeeklyPicks? {
        guard let documentId, let episodeId = Int(documentId) else { return nil }
        var picks = WeeklyPicks(userId: userId, episodeId: episodeId)
        categorySelections?.forEach { key, values in
            if let uuid = UUID(uuidString: key) {
                picks.setSelections(Set(values), for: uuid)
            }
        }
        categoryWagers?.forEach { key, value in
            if let uuid = UUID(uuidString: key) {
                picks.setWager(value, for: uuid)
            }
        }
        picks.isSubmitted = isSubmitted ?? false
        return picks
    }
}
#else

final class FirestoreLeagueRepository {
    static let defaultSeasonId = "season-001"

    init(seasonId: String = FirestoreLeagueRepository.defaultSeasonId, database: Any? = nil) {}

    func invalidate() {}

    func saveSeasonConfig(_ config: SeasonConfig) {}

    func saveEpisodeResult(_ result: EpisodeResult) {}

    func updateSeasonState(activePhaseId: PickPhase.ID?, activatedPhaseIds: Set<PickPhase.ID>) {}

    func savePhases(_ phases: [(PickPhase, Int)]) {}

    func deletePhase(withId id: PickPhase.ID) {}

    func observeSeasonConfig(onChange: @escaping @MainActor (SeasonConfig) -> Void) {}

    func observeSeasonState(onChange: @escaping @MainActor (SeasonStateDocument) -> Void) {}

    func observePhases(onChange: @escaping @MainActor ([PhaseDocument]) -> Void) {}

    func observeResults(onChange: @escaping @MainActor ([EpisodeResult]) -> Void) {}

    func observeUsers(onChange: @escaping @MainActor ([UserProfile]) -> Void) {}

    func observeWeeklyPicks(onChange: @escaping @MainActor ([WeeklyPicks]) -> Void) {}

    func saveWeeklyPicks(_ picks: WeeklyPicks) {}

    func deleteContestantAvatars(for urls: [URL]) {}
}

struct SeasonStateDocument: Codable {
    var activePhaseId: String?
    var activatedPhaseIds: [String]?

    init() {
        self.activePhaseId = nil
        self.activatedPhaseIds = nil
    }

    init(activePhaseId: PickPhase.ID?, activatedPhaseIds: Set<PickPhase.ID>) {
        self.activePhaseId = activePhaseId?.uuidString
        self.activatedPhaseIds = activatedPhaseIds.isEmpty ? nil : activatedPhaseIds.map(\.uuidString)
    }

    init(activePhaseId: String?, activatedPhaseIds: [String]?) {
        self.activePhaseId = activePhaseId
        self.activatedPhaseIds = activatedPhaseIds
    }
}

struct PhaseDocument: Codable {
    var documentId: String?
    var id: String?
    var name: String
    var sortIndex: Int?
    var categories: [PhaseCategoryDocument]

    init(documentId: String? = nil, id: String? = nil, name: String = "", sortIndex: Int? = nil, categories: [PhaseCategoryDocument] = []) {
        self.documentId = documentId
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.categories = categories
    }

    var phaseId: UUID? {
        if let id, let uuid = UUID(uuidString: id) {
            return uuid
        }
        if let documentId, let uuid = UUID(uuidString: documentId) {
            return uuid
        }
        return nil
    }
}

struct PhaseCategoryDocument: Codable {
    var id: String
    var name: String
    var columnId: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var wagerPoints: Int?
    var autoScoresRemainingContestants: Bool = false
    var isLocked: Bool
    var usesWager: Bool?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        columnId: String = "",
        totalPicks: Int = 0,
        pointsPerCorrectPick: Int? = nil,
        wagerPoints: Int? = nil,
        autoScoresRemainingContestants: Bool = false,
        isLocked: Bool = false,
        usesWager: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.columnId = columnId
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.wagerPoints = wagerPoints
        self.autoScoresRemainingContestants = autoScoresRemainingContestants
        self.isLocked = isLocked
        self.usesWager = usesWager
    }

    func model() -> PickPhase.Category? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let shouldUseWager = usesWager ?? (wagerPoints != nil)
        return PickPhase.Category(
            id: uuid,
            name: name,
            columnId: columnId,
            totalPicks: totalPicks,
            pointsPerCorrectPick: pointsPerCorrectPick,
            wagerPoints: wagerPoints,
            autoScoresRemainingContestants: autoScoresRemainingContestants,
            isLocked: isLocked,
            usesWager: shouldUseWager
        )
    }
}

struct EpisodeResultDocument: Codable {
    var documentId: String?
    var phaseId: String?
    var immunityWinners: [String]
    var votedOut: [String]
    var categoryWinners: [String: [String]]?

    init(
        documentId: String? = nil,
        phaseId: String? = nil,
        immunityWinners: [String] = [],
        votedOut: [String] = [],
        categoryWinners: [String: [String]]? = nil
    ) {
        self.documentId = documentId
        self.phaseId = phaseId
        self.immunityWinners = immunityWinners
        self.votedOut = votedOut
        self.categoryWinners = categoryWinners
    }

    var model: EpisodeResult? {
        guard let documentId, let id = Int(documentId) else { return nil }
        var result = EpisodeResult(id: id, phaseId: phaseId.flatMap(UUID.init), immunityWinners: immunityWinners, votedOut: votedOut)
        categoryWinners?.forEach { key, values in
            if let uuid = UUID(uuidString: key) {
                result.setWinners(values, for: uuid)
            }
        }
        return result
    }
}

struct UserDocument: Codable {
    var documentId: String?
    var displayName: String
    var avatarAssetName: String?
    var avatarURL: URL?

    init(documentId: String? = nil, displayName: String = "", avatarAssetName: String? = nil, avatarURL: URL? = nil) {
        self.documentId = documentId
        self.displayName = displayName
        self.avatarAssetName = avatarAssetName
        self.avatarURL = avatarURL
    }

    var model: UserProfile? {
        guard let documentId else { return nil }

        // Prefer the URL stored in Firestore if present; otherwise build from the asset name.
        let resolvedURL: URL? = {
            if let explicit = avatarURL { return explicit }
            if let asset = avatarAssetName, !asset.isEmpty {
                return StoragePaths.userAvatarURL(for: asset)   // builds gs://survivus1514.firebasestorage.app/users/<asset>.png (or .jpg fallback)
            }
            return nil
        }()

        return UserProfile(
            id: documentId,
            displayName: displayName,
            avatarAssetName: avatarAssetName,
            avatarURL: resolvedURL
        )
    }

}

struct WeeklyPicksDocument: Codable {
    var documentId: String?
    var seasonId: String?
    var categorySelections: [String: [String]]?
    var categoryWagers: [String: Int]?
    var isSubmitted: Bool?

    init(
        documentId: String? = nil,
        seasonId: String? = nil,
        categorySelections: [String: [String]]? = nil,
        categoryWagers: [String: Int]? = nil,
        isSubmitted: Bool? = nil
    ) {
        self.documentId = documentId
        self.seasonId = seasonId
        self.categorySelections = categorySelections
        self.categoryWagers = categoryWagers
        self.isSubmitted = isSubmitted
    }

    init(from picks: WeeklyPicks, seasonId: String) {
        self.documentId = String(picks.episodeId)
        self.seasonId = seasonId
        let encodedSelections = picks.categorySelections.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = Array(entry.value)
        }
        categorySelections = encodedSelections.isEmpty ? nil : encodedSelections
        let encodedWagers = picks.categoryWagers.reduce(into: [String: Int]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = entry.value
        }
        categoryWagers = encodedWagers.isEmpty ? nil : encodedWagers
        isSubmitted = picks.isSubmitted
    }

    func model(userId: String) -> WeeklyPicks? {
        guard let documentId, let episodeId = Int(documentId) else { return nil }
        var picks = WeeklyPicks(userId: userId, episodeId: episodeId)
        categorySelections?.forEach { key, values in
            if let uuid = UUID(uuidString: key) {
                picks.setSelections(Set(values), for: uuid)
            }
        }
        categoryWagers?.forEach { key, value in
            if let uuid = UUID(uuidString: key) {
                picks.setWager(value, for: uuid)
            }
        }
        picks.isSubmitted = isSubmitted ?? false
        return picks
    }
}

#endif
