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
    ("parvati_shallow", "Boston Rob"),
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
        let episodes = (1...12).map { index -> Episode in
            Episode(
                id: index,
                airDate: Calendar.current.date(byAdding: .day, value: 7 * (index - 1), to: base)!,
                title: "Week \(index)",
                isMergeEpisode: index == 7
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
