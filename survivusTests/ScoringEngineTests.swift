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

    func testStandardCategoryPointsFollowPhaseConfiguration() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B"),
            Contestant(id: "playerC", name: "Player C")
        ]
        let episodes = [
            Episode(id: 1, title: "Week 1", isMergeEpisode: false)
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

        let phase = PickPhase(
            name: "Custom Phase",
            categories: [
                .init(name: "Remain Safe", columnId: "RM", totalPicks: 3, pointsPerCorrectPick: 2, isLocked: false),
                .init(name: "Voted out", columnId: "VO", totalPicks: 3, pointsPerCorrectPick: 4, isLocked: false),
                .init(name: "Immunity", columnId: "IM", totalPicks: 2, pointsPerCorrectPick: 6, isLocked: false)
            ]
        )
        let resultsByEpisode: [Int: EpisodeResult] = [
            1: EpisodeResult(
                id: 1,
                immunityWinners: ["playerA"],
                votedOut: ["playerB"],
                phaseId: phase.id
            )
        ]
        let engine = ScoringEngine(
            config: config,
            resultsByEpisode: resultsByEpisode,
            phasesById: [phase.id: phase]
        )

        var weekly = WeeklyPicks(userId: "user", episodeId: 1)
        weekly.remain = ["playerC"]
        weekly.votedOut = ["playerB"]
        weekly.immunity = ["playerA"]

        let breakdown = engine.score(weekly: weekly, episode: episodes[0])

        XCTAssertEqual(breakdown.remain, 2)
        XCTAssertEqual(breakdown.votedOut, 4)
        XCTAssertEqual(breakdown.immunity, 6)
    }
}
