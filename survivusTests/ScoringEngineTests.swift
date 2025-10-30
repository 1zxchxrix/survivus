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

        let breakdown = engine.score(weekly: weekly, episode: episodes[1], phaseOverride: nil)

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
                .init(name: "Remain", columnId: "RM", totalPicks: 3, pointsPerCorrectPick: 2, wagerPoints: nil, isLocked: false),
                .init(name: "Voted out", columnId: "VO", totalPicks: 2, pointsPerCorrectPick: 5, wagerPoints: nil, isLocked: false),
                .init(name: "Immunity", columnId: "IM", totalPicks: 2, pointsPerCorrectPick: 4, wagerPoints: nil, isLocked: false)
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

        let breakdown = engine.score(weekly: weekly, episode: episodes[0], phaseOverride: phase)

        XCTAssertEqual(breakdown.remain, 4)
        XCTAssertEqual(breakdown.votedOut, 5)
        XCTAssertEqual(breakdown.immunity, 4)
    }

    func testScoreIgnoresCategoriesOutsideActivePhase() {
        let contestants = [
            Contestant(id: "playerA", name: "Player A"),
            Contestant(id: "playerB", name: "Player B")
        ]
        let episodes = [Episode(id: 1, title: "Finale", isMergeEpisode: true)]
        let config = SeasonConfig(
            seasonId: "test",
            name: "Test Season",
            contestants: contestants,
            episodes: episodes,
            weeklyPickCapsPreMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            weeklyPickCapsPostMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            lockHourUTC: 0
        )

        let activeCategory = PickPhase.Category(
            name: "Fire Winner",
            columnId: "FW",
            totalPicks: 1,
            pointsPerCorrectPick: 5,
            wagerPoints: nil,
            autoScoresRemainers: false,
            isLocked: false
        )
        let inactiveCategory = PickPhase.Category(
            name: "Sole Survivor",
            columnId: "SS",
            totalPicks: 1,
            pointsPerCorrectPick: nil,
            wagerPoints: 30,
            autoScoresRemainers: false,
            isLocked: false
        )

        let phase = PickPhase(name: "Finals", categories: [activeCategory])
        let result = EpisodeResult(
            id: 1,
            phaseId: phase.id,
            immunityWinners: [],
            votedOut: [],
            categoryWinners: [
                activeCategory.id: ["playerA"],
                inactiveCategory.id: ["playerA"]
            ]
        )

        let engine = ScoringEngine(config: config, resultsByEpisode: [1: result])
        var weekly = WeeklyPicks(userId: "user", episodeId: 1)
        weekly.setSelections(Set(["playerA"]), for: activeCategory.id)
        weekly.setSelections(Set(["playerA"]), for: inactiveCategory.id)

        let categoriesById = [
            activeCategory.id: activeCategory,
            inactiveCategory.id: inactiveCategory
        ]

        let breakdown = engine.score(
            weekly: weekly,
            episode: episodes[0],
            phaseOverride: phase,
            categoriesById: categoriesById
        )

        XCTAssertEqual(breakdown.categoryPointsByColumnId.count, 1)
        XCTAssertEqual(breakdown.categoryPointsByColumnId["FW"], 5)
        XCTAssertNil(breakdown.categoryPointsByColumnId["SS"])
    }

    func testWagerCategoryAwardsPointsWhenCorrect() {
        let contestants = [Contestant(id: "playerA", name: "Player A")]
        let episodes = [Episode(id: 1, title: "Finale", isMergeEpisode: true)]
        let config = SeasonConfig(
            seasonId: "test",
            name: "Test Season",
            contestants: contestants,
            episodes: episodes,
            weeklyPickCapsPreMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            weeklyPickCapsPostMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            lockHourUTC: 0
        )

        let wagerCategory = PickPhase.Category(
            name: "Sole Survivor",
            columnId: "SS",
            totalPicks: 1,
            pointsPerCorrectPick: nil,
            wagerPoints: 30,
            autoScoresRemainers: false,
            isLocked: false
        )
        let phase = PickPhase(name: "Finals", categories: [wagerCategory])
        let result = EpisodeResult(
            id: 1,
            phaseId: phase.id,
            immunityWinners: [],
            votedOut: [],
            categoryWinners: [wagerCategory.id: ["playerA"]]
        )

        let engine = ScoringEngine(config: config, resultsByEpisode: [1: result])
        var weekly = WeeklyPicks(userId: "user", episodeId: 1)
        weekly.setSelections(["playerA"], for: wagerCategory.id)

        let breakdown = engine.score(weekly: weekly, episode: episodes[0], phaseOverride: phase, categoriesById: [wagerCategory.id: wagerCategory])

        XCTAssertEqual(breakdown.categoryPointsByColumnId["SS"], 30)
    }

    func testWagerCategorySubtractsPointsWhenIncorrect() {
        let contestants = [Contestant(id: "playerA", name: "Player A"), Contestant(id: "playerB", name: "Player B")]
        let episodes = [Episode(id: 1, title: "Finale", isMergeEpisode: true)]
        let config = SeasonConfig(
            seasonId: "test",
            name: "Test Season",
            contestants: contestants,
            episodes: episodes,
            weeklyPickCapsPreMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            weeklyPickCapsPostMerge: .init(remain: nil, votedOut: nil, immunity: nil),
            lockHourUTC: 0
        )

        let wagerCategory = PickPhase.Category(
            name: "Sole Survivor",
            columnId: "SS",
            totalPicks: 1,
            pointsPerCorrectPick: nil,
            wagerPoints: 30,
            autoScoresRemainers: false,
            isLocked: false
        )
        let phase = PickPhase(name: "Finals", categories: [wagerCategory])
        let result = EpisodeResult(
            id: 1,
            phaseId: phase.id,
            immunityWinners: [],
            votedOut: [],
            categoryWinners: [wagerCategory.id: ["playerB"]]
        )

        let engine = ScoringEngine(config: config, resultsByEpisode: [1: result])
        var weekly = WeeklyPicks(userId: "user", episodeId: 1)
        weekly.setSelections(["playerA"], for: wagerCategory.id)

        let breakdown = engine.score(weekly: weekly, episode: episodes[0], phaseOverride: phase, categoriesById: [wagerCategory.id: wagerCategory])

        XCTAssertEqual(breakdown.categoryPointsByColumnId["SS"], -30)
    }
}
