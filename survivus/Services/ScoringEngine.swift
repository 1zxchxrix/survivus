import Foundation

struct WeeklyScoreBreakdown {
    var votedOut: Int
    var remain: Int
    var immunity: Int
    var categoryPointsByColumnId: [String: Int]
}

struct ScoringEngine {
    let config: SeasonConfig
    let resultsByEpisode: [Int: EpisodeResult]

    func phase(for episode: Episode) -> Phase {
        if episode.isMergeEpisode { return .postMerge }
        let merged = config.episodes.contains(where: { $0.id <= episode.id && $0.isMergeEpisode })
        return merged ? .postMerge : .preMerge
    }

    func score(
        weekly: WeeklyPicks,
        episode: Episode,
        phaseOverride: PickPhase? = nil,
        categoriesById: [PickPhase.Category.ID: PickPhase.Category] = [:]
    ) -> WeeklyScoreBreakdown {
        guard let result = resultsByEpisode[episode.id] else {
            return WeeklyScoreBreakdown(votedOut: 0, remain: 0, immunity: 0, categoryPointsByColumnId: [:])
        }
        let priorEliminations: Set<String> = resultsByEpisode
            .filter { $0.key < episode.id }
            .reduce(into: Set<String>()) { partialResult, entry in
                partialResult.formUnion(entry.value.votedOut)
            }
        let votedOutHits = weekly.votedOut.intersection(result.votedOut).count
        let eligibleRemain = weekly.remain.subtracting(priorEliminations)
        let remainHits = eligibleRemain.subtracting(Set(result.votedOut)).count
        let immunityHits = weekly.immunity.intersection(result.immunityWinners).count
        let defaultPhase = phase(for: episode)
        let remainPointsPerPick = phaseOverride?.remainPointsPerCorrectPick ?? 1
        let votedOutPointsPerPick = phaseOverride?.votedOutPointsPerCorrectPick ?? 3
        let immunityPointsPerPick = phaseOverride?.immunityPointsPerCorrectPick ?? ((defaultPhase == .preMerge) ? 1 : 3)
        let remainPoints = remainHits * remainPointsPerPick
        let votedOutPoints = votedOutHits * votedOutPointsPerPick
        let immunityPts = immunityHits * immunityPointsPerPick
        var categoryPoints: [String: Int] = [:]

        for (categoryId, winners) in result.categoryWinners {
            guard let category = categoriesById[categoryId] else { continue }
            guard
                !category.matchesRemainCategory,
                !category.matchesVotedOutCategory,
                !category.matchesImmunityCategory
            else {
                continue
            }

            guard let pointsPerPick = category.pointsPerCorrectPick, pointsPerPick > 0 else { continue }
            let hits = weekly.selections(for: categoryId).intersection(Set(winners)).count
            guard hits > 0 else { continue }

            let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !columnId.isEmpty else { continue }

            categoryPoints[columnId, default: 0] += hits * pointsPerPick
        }

        return WeeklyScoreBreakdown(
            votedOut: votedOutPoints,
            remain: remainPoints,
            immunity: immunityPts,
            categoryPointsByColumnId: categoryPoints
        )
    }

    func mergeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.mergePicks.isEmpty else { return 0 }
        var pts = 0
        var eliminated: Set<String> = []
        for id in episodeIds(upTo: episodeId) {
            guard let res = resultsByEpisode[id] else { continue }
            eliminated.formUnion(res.votedOut)
            let alive = seasonPicks.mergePicks.subtracting(eliminated)
            pts += alive.count
        }
        return pts
    }

    func finalThreeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.finalThreePicks.isEmpty else { return 0 }
        var pts = 0
        var eliminated: Set<String> = []
        for id in episodeIds(upTo: episodeId) {
            guard let res = resultsByEpisode[id] else { continue }
            eliminated.formUnion(res.votedOut)
            let alive = seasonPicks.finalThreePicks.subtracting(eliminated)
            pts += alive.count
        }
        return pts
    }

    func winnerPoints(seasonPicks: SeasonPicks, finalResult: EpisodeResult?) -> Int {
        guard let winnerId = soleSurvivorId(finalResult: finalResult), let pick = seasonPicks.winnerPick else { return 0 }
        return (winnerId == pick) ? 5 : 0
    }

    func soleSurvivorId(finalResult: EpisodeResult?) -> String? {
        return nil
    }
}

private extension ScoringEngine {
    func episodeIds(upTo upperBound: Int) -> [Int] {
        var idSet = Set(config.episodes.map(\.id))
        idSet.formUnion(resultsByEpisode.keys)

        return idSet
            .filter { $0 <= upperBound }
            .sorted()
    }
}
