import Foundation

struct UserProfile: Identifiable, Hashable, Codable {
    let id: String
    var displayName: String
    var avatarAssetName: String
}

struct UserScoreBreakdown: Identifiable, Hashable, Codable {
    var id: String { userId }
    let userId: String
    var weeksParticipated: Int
    var votedOutPoints: Int
    var remainPoints: Int
    var immunityPoints: Int
    var mergeTrackPoints: Int
    var finalThreeTrackPoints: Int
    var winnerPoints: Int
    var total: Int { votedOutPoints + remainPoints + immunityPoints + mergeTrackPoints + finalThreeTrackPoints + winnerPoints }
}
