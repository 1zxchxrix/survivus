import Foundation

extension SeasonConfig {
    static func mock() -> SeasonConfig {
        let contestants: [Contestant] = [
            .init(id: "c01", name: "Alex"),
            .init(id: "c02", name: "Bailey"),
            .init(id: "c03", name: "Casey"),
            .init(id: "c04", name: "Drew"),
            .init(id: "c05", name: "Eden"),
            .init(id: "c06", name: "Finn"),
            .init(id: "c07", name: "Gray"),
            .init(id: "c08", name: "Harper"),
            .init(id: "c09", name: "Indy"),
            .init(id: "c10", name: "Jules"),
            .init(id: "c11", name: "Kai"),
            .init(id: "c12", name: "Lane")
        ]
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
        let immunity = ["c0\(((episodeId - 1) % 3) + 1)"]
        let votedOut = episodeId <= 10 ? ["c0\(((episodeId) % 12) + 1)"] : []
        return EpisodeResult(id: episodeId, immunityWinners: immunity, votedOut: votedOut)
    }
}
