import XCTest
@testable import survivus

final class ScoringEngineTests: XCTestCase {
    func testRemainPicksDoNotScoreForPreviouslyEliminatedContestants() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B"),
            Contestant(id: "playerC", name: "Player C")
        ]
        let episodes = [
            Episode(id: 1, title: "Week 1", isMergeEpisode: false),
            Episode(id: 2, title: "Week 2", isMergeEpisode: false)
        ]
        let config = SeasonConfig(
            seasonId: "test",
            name: "Test Season",
            contestants: contestants,
            episodes: episodes,
            weeklyPickCapsPreMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            weeklyPickCapsPostMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            lockHourUTC: 0
        )

        let resultsByEpisode: [Int: EpisodeResult] = [
            1: EpisodeResult(id: 1, immunityWinners: [], votedOut: ["playerA"]),
            2: EpisodeResult(id: 2, immunityWinners: [], votedOut: ["playerB"])
        ]

        let engine = ScoringEngine(config: config, resultsByEpisode: resultsByEpisode)
        var weekly = WeeklyPicks(userId: "user", episodeId: 2)
        weekly.remain = ["playerA"]

        let breakdown = engine.score(weekly: weekly, episode: episodes[1])

        XCTAssertEqual(breakdown.remain, 0)
    }
}
