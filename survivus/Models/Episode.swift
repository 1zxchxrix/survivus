import Foundation

struct Episode: Identifiable, Hashable {
    let id: Int
    var airDate: Date?
    var title: String
    var isMergeEpisode: Bool

    init(
        id: Int,
        airDate: Date? = nil,
        title: String? = nil,
        isMergeEpisode: Bool = false
    ) {
        self.id = id
        self.airDate = airDate
        let resolvedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.title = resolvedTitle.isEmpty ? "Week \(id)" : resolvedTitle
        self.isMergeEpisode = isMergeEpisode
    }
}

extension Episode: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case airDate
        case title
        case isMergeEpisode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Int.self, forKey: .id)
        let airDate = try container.decodeIfPresent(Date.self, forKey: .airDate)
        let title = try container.decodeIfPresent(String.self, forKey: .title)
        let isMergeEpisode = try container.decodeIfPresent(Bool.self, forKey: .isMergeEpisode) ?? false
        self.init(id: id, airDate: airDate, title: title, isMergeEpisode: isMergeEpisode)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(airDate, forKey: .airDate)
        try container.encode(title, forKey: .title)
        try container.encode(isMergeEpisode, forKey: .isMergeEpisode)
    }
}

enum Phase: String, Codable {
    case preMerge
    case postMerge
}

struct EpisodeResult: Identifiable, Hashable, Codable {
    let id: Int
    var immunityWinners: [String]
    var votedOut: [String]
    var phaseId: PickPhase.ID?
    var categoryWinners: [UUID: [String]] = [:]
}

extension EpisodeResult {
    var hasRecordedResults: Bool {
        if !immunityWinners.isEmpty || !votedOut.isEmpty {
            return true
        }

        return categoryWinners.contains { !$0.value.isEmpty }
    }

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
