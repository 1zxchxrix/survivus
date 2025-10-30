import Foundation

private let mockContestantData: [(id: String, name: String)] = [
    ("courtney_yates", "Courtney Yates"),
    ("todd_herzog", "Todd Herzog"),
    ("boston_rob", "Boston Rob"),
    ("russell_hantz", "Russell Hantz"),
    ("john_cochran", "John Cochran"),
    ("tony_vlachos", "Tony Vlachos"),
    ("q", "Q"),
    ("eva_erickson", "Eva Erickson"),
    ("mitch_guerra", "Mitch Guerra"),
    ("erik_reichenbach", "Erik Reichenbach"),
    ("yul_kwon", "Yul Kwon"),
    ("ozzy_lusth", "Ozzy Lusth"),
    ("parvati_shallow", "Parvati Shallow"),
    ("jonathan_penner", "Jonathan Penner"),
    ("nate_gonzalez", "Nate Gonzalez"),
    ("chicken_morris", "Chicken Morris"),
    ("frosti_zernow", "Frosti Zernow"),
    ("james_clement", "James Clement"),
    ("denise_martin", "Denise Martin"),
    ("amanda_kimmel", "Amanda Kimmel")
]

extension SeasonConfig {
    static func mock() -> SeasonConfig {
        let contestants: [Contestant] = mockContestantData.map { .init(id: $0.id, name: $0.name) }
        let base = Date()
        let episodes = (1...2).map { index -> Episode in
            Episode(
                id: index,
                airDate: Calendar.current.date(byAdding: .day, value: 7 * (index - 1), to: base)!,
                title: "Week \(index)",
                isMergeEpisode: false
            )
        }
        return SeasonConfig(seasonId: "S00", name: "Mock Season", contestants: contestants, episodes: episodes)
    }
}

extension EpisodeResult {
    static func mock(episodeId: Int) -> EpisodeResult {
        let contestantIds = mockContestantData.map { $0.id }
        let immunity = [contestantIds[(episodeId - 1) % contestantIds.count]]
        let votedOut = episodeId <= contestantIds.count ? [contestantIds[episodeId % contestantIds.count]] : []
        return EpisodeResult(id: episodeId, immunityWinners: immunity, votedOut: votedOut)
    }
}

private let mockWeeklyPicksData: [String: [WeeklyPicks]] = [
    "u1": [
        WeeklyPicks(
            userId: "u1",
            episodeId: 1,
            remain: Set(["q", "eva_erickson", "tony_vlachos", "john_cochran"]),
            votedOut: Set(["todd_herzog"]),
            immunity: Set(["q"])
        ),
        WeeklyPicks(
            userId: "u1",
            episodeId: 2,
            remain: Set(["eva_erickson", "tony_vlachos", "john_cochran"]),
            votedOut: Set(["boston_rob"]),
            immunity: Set(["eva_erickson"])
        )
    ],
    "u2": [
        WeeklyPicks(
            userId: "u2",
            episodeId: 1,
            remain: Set(["parvati_shallow", "john_cochran", "ozzy_lusth"]),
            votedOut: Set(["russell_hantz"]),
            immunity: Set(["john_cochran"])
        ),
        WeeklyPicks(
            userId: "u2",
            episodeId: 2,
            remain: Set(["parvati_shallow", "john_cochran", "ozzy_lusth"]),
            votedOut: Set(["eva_erickson"]),
            immunity: Set(["ozzy_lusth"])
        )
    ],
    "u3": [
        WeeklyPicks(
            userId: "u3",
            episodeId: 1,
            remain: Set(["john_cochran", "ozzy_lusth", "denise_martin"]),
            votedOut: Set(["tony_vlachos"]),
            immunity: Set(["denise_martin"])
        ),
        WeeklyPicks(
            userId: "u3",
            episodeId: 2,
            remain: Set(["john_cochran", "denise_martin"]),
            votedOut: Set(["mitch_guerra"]),
            immunity: Set(["john_cochran"])
        )
    ],
    "u4": [
        WeeklyPicks(
            userId: "u4",
            episodeId: 1,
            remain: Set(["amanda_kimmel", "yul_kwon", "erik_reichenbach"]),
            votedOut: Set(["q"]),
            immunity: Set(["amanda_kimmel"])
        ),
        WeeklyPicks(
            userId: "u4",
            episodeId: 2,
            remain: Set(["amanda_kimmel", "yul_kwon", "erik_reichenbach"]),
            votedOut: Set(["erik_reichenbach"]),
            immunity: Set(["yul_kwon"])
        )
    ]
]

extension MemoryStore {
    func loadMockPicks() {
        let seededWeeklyPicks = Dictionary(uniqueKeysWithValues: users.map { user in
            let picksByEpisode = mockWeeklyPicksData[user.id]?.reduce(into: [Int: WeeklyPicks]()) { partialResult, picks in
                partialResult[picks.episodeId] = picks
            } ?? [:]
            return (user.id, picksByEpisode)
        })

        weeklyPicks = seededWeeklyPicks
    }
}
