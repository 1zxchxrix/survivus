import Foundation

struct UserProfile: Identifiable, Hashable, Codable {
    let id: String
    var displayName: String
    var avatarAssetName: String?
    var avatarURL: URL?

    init(id: String, displayName: String, avatarAssetName: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.avatarAssetName = avatarAssetName
        self.avatarURL = avatarURL
    }
}

struct UserScoreBreakdown: Identifiable, Hashable, Codable {
    var id: String { userId }
    let userId: String
    var weeksParticipated: Int
    var votedOutPoints: Int
    var remainPoints: Int
    var immunityPoints: Int
    var categoryPointsByColumnId: [String: Int]

    init(
        userId: String,
        weeksParticipated: Int,
        votedOutPoints: Int,
        remainPoints: Int,
        immunityPoints: Int,
        categoryPointsByColumnId: [String: Int] = [:]
    ) {
        self.userId = userId
        self.weeksParticipated = weeksParticipated
        self.votedOutPoints = votedOutPoints
        self.remainPoints = remainPoints
        self.immunityPoints = immunityPoints
        self.categoryPointsByColumnId = categoryPointsByColumnId
    }

    var total: Int {
        votedOutPoints
            + remainPoints
            + immunityPoints
            + categoryPointsByColumnId.values.reduce(0, +)
    }

    func points(forColumnId columnId: String) -> Int {
        let normalized = columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return categoryPointsByColumnId[normalized] ?? 0
    }
}
