import Foundation

struct Episode: Identifiable, Hashable, Codable {
    let id: Int
    var airDate: Date
    var title: String
    var isMergeEpisode: Bool
}

enum Phase: String, Codable {
    case preMerge
    case postMerge
}

struct EpisodeResult: Identifiable, Hashable, Codable {
    let id: Int
    var immunityWinners: [String]
    var votedOut: [String]
    var categoryWinners: [UUID: [String]] = [:]
}

extension EpisodeResult {
    func winners(for categoryId: UUID) -> [String] {
        categoryWinners[categoryId] ?? []
    }

    mutating func setWinners(_ winners: [String], for categoryId: UUID) {
        if winners.isEmpty {
            categoryWinners.removeValue(forKey: categoryId)
        } else {
            categoryWinners[categoryId] = winners
        }
    }
}
