import Foundation

struct SeasonConfig: Codable {
    struct WeeklyPickCaps: Codable {
        var remain: Int?
        var votedOut: Int?
        var immunity: Int?
    }

    var seasonId: String
    var name: String
    var contestants: [Contestant]
    var episodes: [Episode]
    var weeklyPickCapsPreMerge: WeeklyPickCaps
    var weeklyPickCapsPostMerge: WeeklyPickCaps
    var lockHourUTC: Int

    init(
        seasonId: String,
        name: String,
        contestants: [Contestant],
        episodes: [Episode] = [],
        weeklyPickCapsPreMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: 3),
        weeklyPickCapsPostMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: nil),
        lockHourUTC: Int = 23
    ) {
        self.seasonId = seasonId
        self.name = name
        self.contestants = contestants
        self.episodes = episodes
        self.weeklyPickCapsPreMerge = weeklyPickCapsPreMerge
        self.weeklyPickCapsPostMerge = weeklyPickCapsPostMerge
        self.lockHourUTC = lockHourUTC
    }
}

extension SeasonConfig {
    static var placeholder: SeasonConfig {
        SeasonConfig(seasonId: "loading", name: "Loading…", contestants: [], episodes: [])
    }
}

extension SeasonConfig {
    private enum CodingKeys: String, CodingKey {
        case seasonId
        case name
        case contestants
        case episodes
        case weeklyPickCapsPreMerge
        case weeklyPickCapsPostMerge
        case lockHourUTC
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seasonId = try container.decode(String.self, forKey: .seasonId)
        name = try container.decode(String.self, forKey: .name)
        contestants = try container.decodeIfPresent([Contestant].self, forKey: .contestants) ?? []
        episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
        weeklyPickCapsPreMerge = try container.decodeIfPresent(WeeklyPickCaps.self, forKey: .weeklyPickCapsPreMerge)
            ?? .init(remain: 3, votedOut: 3, immunity: 3)
        weeklyPickCapsPostMerge = try container.decodeIfPresent(WeeklyPickCaps.self, forKey: .weeklyPickCapsPostMerge)
            ?? .init(remain: 3, votedOut: 3, immunity: nil)
        lockHourUTC = try container.decodeIfPresent(Int.self, forKey: .lockHourUTC) ?? 23
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seasonId, forKey: .seasonId)
        try container.encode(name, forKey: .name)
        try container.encode(contestants, forKey: .contestants)
        try container.encode(episodes, forKey: .episodes)
        try container.encode(weeklyPickCapsPreMerge, forKey: .weeklyPickCapsPreMerge)
        try container.encode(weeklyPickCapsPostMerge, forKey: .weeklyPickCapsPostMerge)
        try container.encode(lockHourUTC, forKey: .lockHourUTC)
    }
}
