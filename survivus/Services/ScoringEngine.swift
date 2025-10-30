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
        let remainPointsPerPick: Int
        let votedOutPointsPerPick: Int
        let immunityPointsPerPick: Int

        if let phaseOverride {
            remainPointsPerPick = max(phaseOverride.remainPointsPerCorrectPick ?? 0, 0)
            votedOutPointsPerPick = max(phaseOverride.votedOutPointsPerCorrectPick ?? 0, 0)
            immunityPointsPerPick = max(phaseOverride.immunityPointsPerCorrectPick ?? 0, 0)
        } else {
            if let category = categoriesById.values.first(where: { $0.matchesRemainCategory }),
               let points = category.pointsPerCorrectPick {
                remainPointsPerPick = max(points, 0)
            } else {
                remainPointsPerPick = 0
            }
            votedOutPointsPerPick = 3
            immunityPointsPerPick = (defaultPhase == .preMerge) ? 1 : 3
        }

        let remainPoints = remainHits * remainPointsPerPick
        let votedOutPoints = votedOutHits * votedOutPointsPerPick
        let immunityPts = immunityHits * immunityPointsPerPick
        var categoryPoints: [String: Int] = [:]
        let activeCategoryIds: Set<UUID>? = phaseOverride.map { phase in
            Set(phase.categories.map(\.id))
        }

        let categoriesLookup: (UUID) -> PickPhase.Category? = { id in
            if let category = phaseOverride?.categories.first(where: { $0.id == id }) {
                return category
            }
            return categoriesById[id]
        }

        for (categoryId, winners) in result.categoryWinners {
            if let activeCategoryIds, !activeCategoryIds.contains(categoryId) {
                continue
            }

            guard let category = categoriesLookup(categoryId) else { continue }
            guard
                !category.matchesRemainCategory,
                !category.matchesVotedOutCategory,
                !category.matchesImmunityCategory
            else {
                continue
            }

            let selections = weekly.selections(for: categoryId)
            let hits = selections.intersection(Set(winners)).count
            let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !columnId.isEmpty else { continue }

            if let pointsPerPick = category.pointsPerCorrectPick, pointsPerPick != 0 {
                guard hits > 0 else { continue }
                categoryPoints[columnId, default: 0] += hits * pointsPerPick
            } else if let wager = category.wagerPoints, wager != 0 {
                guard !selections.isEmpty, !winners.isEmpty else { continue }
                let delta = hits > 0 ? wager : -wager
                categoryPoints[columnId, default: 0] += delta
            }
        }

        return WeeklyScoreBreakdown(
            votedOut: votedOutPoints,
            remain: remainPoints,
            immunity: immunityPts,
            categoryPointsByColumnId: categoryPoints
        )
    }
}
