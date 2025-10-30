import Foundation

enum MockContent {
    enum CategoryID {
        static let remain = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let votedOut = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        static let immunity = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    }

    static let phaseId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

    static let categories: [PickPhase.Category] = [
        .init(
            id: CategoryID.remain,
            name: "Remain",
            columnId: "RM",
            totalPicks: 4,
            pointsPerCorrectPick: 1,
            wagerPoints: nil,
            autoScoresRemainingContestants: true,
            isLocked: false
        ),
        .init(
            id: CategoryID.votedOut,
            name: "Voted Out",
            columnId: "VO",
            totalPicks: 1,
            pointsPerCorrectPick: 3,
            wagerPoints: nil,
            autoScoresRemainingContestants: false,
            isLocked: false
        ),
        .init(
            id: CategoryID.immunity,
            name: "Immunity",
            columnId: "IM",
            totalPicks: 1,
            pointsPerCorrectPick: 3,
            wagerPoints: nil,
            autoScoresRemainingContestants: false,
            isLocked: false
        )
    ]

    static let phases: [PickPhase] = [
        PickPhase(
            id: phaseId,
            name: "Mock Phase",
            categories: categories
        )
    ]

    static let categoriesById: [UUID: PickPhase.Category] =
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
}

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
        var categoryWinners: [UUID: [String]] = [:]
        if !immunity.isEmpty {
            categoryWinners[MockContent.CategoryID.immunity] = immunity
        }
        if !votedOut.isEmpty {
            categoryWinners[MockContent.CategoryID.votedOut] = votedOut
        }
        return EpisodeResult(
            id: episodeId,
            phaseId: MockContent.phaseId,
            immunityWinners: immunity,
            votedOut: votedOut,
            categoryWinners: categoryWinners
        )
    }
}

private let mockWeeklySelections: [String: [Int: [UUID: Set<String>]]] = [
    "u1": [
        1: [
            MockContent.CategoryID.remain: ["q", "eva_erickson", "tony_vlachos", "john_cochran"],
            MockContent.CategoryID.votedOut: ["todd_herzog"],
            MockContent.CategoryID.immunity: ["q"]
        ].mapValues(Set.init),
        2: [
            MockContent.CategoryID.remain: ["eva_erickson", "tony_vlachos", "john_cochran"],
            MockContent.CategoryID.votedOut: ["boston_rob"],
            MockContent.CategoryID.immunity: ["eva_erickson"]
        ].mapValues(Set.init)
    ],
    "u2": [
        1: [
            MockContent.CategoryID.remain: ["parvati_shallow", "john_cochran", "ozzy_lusth"],
            MockContent.CategoryID.votedOut: ["russell_hantz"],
            MockContent.CategoryID.immunity: ["john_cochran"]
        ].mapValues(Set.init),
        2: [
            MockContent.CategoryID.remain: ["parvati_shallow", "john_cochran", "ozzy_lusth"],
            MockContent.CategoryID.votedOut: ["eva_erickson"],
            MockContent.CategoryID.immunity: ["ozzy_lusth"]
        ].mapValues(Set.init)
    ],
    "u3": [
        1: [
            MockContent.CategoryID.remain: ["john_cochran", "ozzy_lusth", "denise_martin"],
            MockContent.CategoryID.votedOut: ["tony_vlachos"],
            MockContent.CategoryID.immunity: ["denise_martin"]
        ].mapValues(Set.init),
        2: [
            MockContent.CategoryID.remain: ["john_cochran", "denise_martin"],
            MockContent.CategoryID.votedOut: ["mitch_guerra"],
            MockContent.CategoryID.immunity: ["john_cochran"]
        ].mapValues(Set.init)
    ],
    "u4": [
        1: [
            MockContent.CategoryID.remain: ["amanda_kimmel", "yul_kwon", "erik_reichenbach"],
            MockContent.CategoryID.votedOut: ["q"],
            MockContent.CategoryID.immunity: ["amanda_kimmel"]
        ].mapValues(Set.init),
        2: [
            MockContent.CategoryID.remain: ["amanda_kimmel", "yul_kwon", "erik_reichenbach"],
            MockContent.CategoryID.votedOut: ["erik_reichenbach"],
            MockContent.CategoryID.immunity: ["yul_kwon"]
        ].mapValues(Set.init)
    ]
]

extension MemoryStore {
    func loadMockPicks() {
        let seededWeeklyPicks = Dictionary(uniqueKeysWithValues: users.map { user in
            let picksByEpisode = mockWeeklySelections[user.id]?.reduce(into: [Int: WeeklyPicks]()) { partialResult, entry in
                let (episodeId, selectionsByCategory) = entry
                var picks = WeeklyPicks(userId: user.id, episodeId: episodeId)
                for (categoryId, selections) in selectionsByCategory {
                    picks.setSelections(selections, for: categoryId)
                }
                partialResult[episodeId] = picks
            } ?? [:]
            return (user.id, picksByEpisode)
        })

        weeklyPicks = seededWeeklyPicks
    }
}
