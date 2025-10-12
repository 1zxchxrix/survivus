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
    var weeklyPickCapsPreMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: 3)
    var weeklyPickCapsPostMerge: WeeklyPickCaps = .init(remain: 3, votedOut: 3, immunity: nil)
    var lockHourUTC: Int = 23
}

extension SeasonConfig {
    static var placeholder: SeasonConfig {
        SeasonConfig(seasonId: "loading", name: "Loading…", contestants: [], episodes: [])
    }
}
