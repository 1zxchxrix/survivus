import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

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
            guard error == nil, let snapshot, snapshot.exists else { return }
            do {
                let config = try snapshot.data(as: SeasonConfig.self)
                Task { @MainActor in onChange(config) }
            } catch {
                logDecodingError(error, context: "SeasonConfig")
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
            guard error == nil else { return }
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
            guard error == nil, let documents = snapshot?.documents else { return }
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
            guard error == nil, let documents = snapshot?.documents else { return }
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
            guard error == nil, let documents = snapshot?.documents else { return }
            let users: [UserProfile] = documents.compactMap { document in
                do {
                    let payload = try document.data(as: UserDocument.self)
                    return payload.model
                } catch {
                    self.logDecodingError(error, context: "UserDocument")
                    return nil
                }
            }
            Task { @MainActor in onChange(users.sorted(by: { $0.displayName < $1.displayName })) }
        })
    }

    func observeSeasonPicks(onChange: @escaping @MainActor ([SeasonPicks]) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("seasonPicks")

        register(reference.addSnapshotListener { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else { return }
            let picks: [SeasonPicks] = documents.compactMap { document in
                do {
                    let payload = try document.data(as: SeasonPicksDocument.self)
                    return payload.model
                } catch {
                    self.logDecodingError(error, context: "SeasonPicksDocument")
                    return nil
                }
            }
            Task { @MainActor in onChange(picks) }
        })
    }

    func observeWeeklyPicks(onChange: @escaping @MainActor ([WeeklyPicks]) -> Void) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collectionGroup("episodes")

        register(reference.addSnapshotListener { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else { return }
            let picks: [WeeklyPicks] = documents.compactMap { document in
                do {
                    let payload = try document.data(as: WeeklyPicksDocument.self)
                    guard let userId = document.reference.parent.parent?.documentID else { return nil }
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

    func saveSeasonPicks(_ picks: SeasonPicks) {
        let reference = database
            .collection("seasons")
            .document(seasonId)
            .collection("seasonPicks")
            .document(picks.userId)

        let payload = SeasonPicksDocument(from: picks)
        do {
            try reference.setData(from: payload, merge: true)
        } catch {
            logEncodingError(error, context: "SeasonPicks")
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

        let payload = WeeklyPicksDocument(from: picks)
        do {
            try reference.setData(from: payload, merge: true)
        } catch {
            logEncodingError(error, context: "WeeklyPicks")
        }
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
}

// MARK: - Firestore payloads

struct SeasonStateDocument: Codable {
    var activePhaseId: String?
    var activatedPhaseIds: [String]?
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
}

struct PhaseCategoryDocument: Codable {
    var id: String
    var name: String
    var columnId: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var isLocked: Bool

    func model() -> PickPhase.Category? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return PickPhase.Category(
            id: uuid,
            name: name,
            columnId: columnId,
            totalPicks: totalPicks,
            pointsPerCorrectPick: pointsPerCorrectPick,
            isLocked: isLocked
        )
    }
}

struct EpisodeResultDocument: Codable {
    @DocumentID var documentId: String?
    var immunityWinners: [String]
    var votedOut: [String]
    var categoryWinners: [String: [String]]?

    var model: EpisodeResult? {
        guard let documentId, let id = Int(documentId) else { return nil }
        var result = EpisodeResult(id: id, immunityWinners: immunityWinners, votedOut: votedOut)
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
    var avatarAssetName: String

    var model: UserProfile? {
        guard let documentId else { return nil }
        return UserProfile(id: documentId, displayName: displayName, avatarAssetName: avatarAssetName)
    }
}

struct SeasonPicksDocument: Codable {
    @DocumentID var documentId: String?
    var mergePicks: [String]?
    var finalThreePicks: [String]?
    var winnerPick: String?

    init() {}

    init(from picks: SeasonPicks) {
        mergePicks = Array(picks.mergePicks)
        finalThreePicks = Array(picks.finalThreePicks)
        winnerPick = picks.winnerPick
    }

    var model: SeasonPicks? {
        guard let documentId else { return nil }
        var picks = SeasonPicks(userId: documentId)
        if let mergePicks { picks.mergePicks = Set(mergePicks) }
        if let finalThreePicks { picks.finalThreePicks = Set(finalThreePicks) }
        picks.winnerPick = winnerPick
        return picks
    }
}

struct WeeklyPicksDocument: Codable {
    @DocumentID var documentId: String?
    var remain: [String]?
    var votedOut: [String]?
    var immunity: [String]?
    var categorySelections: [String: [String]]?

    init() {}

    init(from picks: WeeklyPicks) {
        remain = Array(picks.remain)
        votedOut = Array(picks.votedOut)
        immunity = Array(picks.immunity)
        categorySelections = picks.categorySelections.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = Array(entry.value)
        }
    }

    func model(userId: String) -> WeeklyPicks? {
        guard let documentId, let episodeId = Int(documentId) else { return nil }
        var picks = WeeklyPicks(userId: userId, episodeId: episodeId)
        if let remain { picks.remain = Set(remain) }
        if let votedOut { picks.votedOut = Set(votedOut) }
        if let immunity { picks.immunity = Set(immunity) }
        categorySelections?.forEach { key, values in
            if let uuid = UUID(uuidString: key) {
                picks.setSelections(Set(values), for: uuid)
            }
        }
        return picks
    }
}
