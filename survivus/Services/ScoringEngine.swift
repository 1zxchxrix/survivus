import Foundation

struct WeeklyScoreBreakdown {
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
            return WeeklyScoreBreakdown(categoryPointsByColumnId: [:])
        }
        let priorEliminations: Set<String> = resultsByEpisode
            .filter { $0.key < episode.id }
            .reduce(into: Set<String>()) { partialResult, entry in
                partialResult.formUnion(entry.value.votedOut)
            }
        let currentVotedOut = Set(result.votedOut)
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

        let winnersByCategory: [UUID: Set<String>] = result.categoryWinners.mapValues { Set($0) }
        var categoryIdsToScore = Set(winnersByCategory.keys)

        if let activeCategoryIds {
            for categoryId in activeCategoryIds {
                if let category = categoriesLookup(categoryId), category.autoScoresRemainingContestants {
                    categoryIdsToScore.insert(categoryId)
                }
            }
        } else {
            for (categoryId, category) in categoriesById where category.autoScoresRemainingContestants {
                categoryIdsToScore.insert(categoryId)
            }
        }

        for categoryId in categoryIdsToScore {
            if let activeCategoryIds, !activeCategoryIds.contains(categoryId) {
                continue
            }

            guard let category = categoriesLookup(categoryId) else { continue }
            let selections = weekly.selections(for: categoryId)
            let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !columnId.isEmpty else { continue }

            if category.autoScoresRemainingContestants {
                guard let pointsPerPick = category.pointsPerCorrectPick, pointsPerPick != 0 else { continue }
                guard !selections.isEmpty else { continue }
                let remainingSelections = selections
                    .subtracting(priorEliminations)
                    .subtracting(currentVotedOut)
                guard !remainingSelections.isEmpty else { continue }
                categoryPoints[columnId, default: 0] += remainingSelections.count * pointsPerPick
                continue
            }

            guard let winners = winnersByCategory[categoryId], !winners.isEmpty else { continue }
            let hits = selections.intersection(winners).count

            if let pointsPerPick = category.pointsPerCorrectPick, pointsPerPick != 0 {
                guard hits > 0 else { continue }
                categoryPoints[columnId, default: 0] += hits * pointsPerPick
            } else if let wager = category.wagerPoints, wager != 0 {
                guard !selections.isEmpty else { continue }
                let delta = hits > 0 ? wager : -wager
                categoryPoints[columnId, default: 0] += delta
            }
        }

        return WeeklyScoreBreakdown(
            categoryPointsByColumnId: categoryPoints
        )
    }
}
