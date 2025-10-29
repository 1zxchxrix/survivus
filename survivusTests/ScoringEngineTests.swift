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

        let breakdown = engine.score(weekly: weekly, episode: episodes[1], phase: nil)

        XCTAssertEqual(breakdown.remain, 0)
    }

    func testScoreRespectsPhaseSpecificPointValues() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B"),
            Contestant(id: "playerC", name: "Player C")
        ]
        let episodes = [Episode(id: 1, title: "Week 1", isMergeEpisode: false)]
        let config = SeasonConfig(
            seasonId: "test",
            name: "Test Season",
            contestants: contestants,
            episodes: episodes,
            weeklyPickCapsPreMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            weeklyPickCapsPostMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            lockHourUTC: 0
        )

        let phase = PickPhase(
            name: "Post-merge",
            categories: [
                .init(name: "Remain", columnId: "RM", totalPicks: 3, pointsPerCorrectPick: 2, isLocked: false),
                .init(name: "Voted out", columnId: "VO", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false),
                .init(name: "Immunity", columnId: "IM", totalPicks: 2, pointsPerCorrectPick: 4, isLocked: false)
            ]
        )

        let result = EpisodeResult(
            id: 1,
            phaseId: phase.id,
            immunityWinners: ["playerB"],
            votedOut: ["playerC"]
        )

        let engine = ScoringEngine(config: config, resultsByEpisode: [1: result])
        var weekly = WeeklyPicks(userId: "user", episodeId: 1)
        weekly.remain = ["playerA", "playerB"]
        weekly.votedOut = ["playerC"]
        weekly.immunity = ["playerB"]

        let breakdown = engine.score(weekly: weekly, episode: episodes[0], phase: phase)

        XCTAssertEqual(breakdown.remain, 4)
        XCTAssertEqual(breakdown.votedOut, 5)
        XCTAssertEqual(breakdown.immunity, 4)
    }

    func testMergeTrackPointsStopAfterElimination() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B")
        ]
        let episodes = [
            Episode(id: 1, title: "Week 1", isMergeEpisode: false),
            Episode(id: 2, title: "Week 2", isMergeEpisode: true),
            Episode(id: 3, title: "Week 3", isMergeEpisode: true)
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
            1: EpisodeResult(id: 1, immunityWinners: [], votedOut: []),
            2: EpisodeResult(id: 2, immunityWinners: [], votedOut: ["playerA"]),
            3: EpisodeResult(id: 3, immunityWinners: [], votedOut: [])
        ]

        let engine = ScoringEngine(config: config, resultsByEpisode: resultsByEpisode)
        let seasonPicks = SeasonPicks(userId: "user", mergePicks: ["playerA", "playerB"])

        let points = engine.mergeTrackPoints(for: "user", upTo: 3, seasonPicks: seasonPicks)

        XCTAssertEqual(points, 4)
    }

    func testFinalThreeTrackPointsStopAfterElimination() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B"),
            Contestant(id: "playerC", name: "Player C")
        ]
        let episodes = [
            Episode(id: 1, title: "Week 1", isMergeEpisode: false),
            Episode(id: 2, title: "Week 2", isMergeEpisode: true),
            Episode(id: 3, title: "Week 3", isMergeEpisode: true)
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
            1: EpisodeResult(id: 1, immunityWinners: [], votedOut: []),
            2: EpisodeResult(id: 2, immunityWinners: [], votedOut: ["playerB"]),
            3: EpisodeResult(id: 3, immunityWinners: [], votedOut: [])
        ]

        let engine = ScoringEngine(config: config, resultsByEpisode: resultsByEpisode)
        let seasonPicks = SeasonPicks(userId: "user", finalThreePicks: ["playerA", "playerB", "playerC"])

        let points = engine.finalThreeTrackPoints(for: "user", upTo: 3, seasonPicks: seasonPicks)

        XCTAssertEqual(points, 7)
    }
}
