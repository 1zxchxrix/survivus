import Foundation

struct WeeklyScoreBreakdown {
    var categoryPointsByColumnId: [String: Int]
}

/// ScoringEngine v2 — simplified to match Edit Category:
/// - Supports "Normal" scoring (pointsPerCorrectPick) and wager-based scoring.
/// - Optional Auto-score: points for each selection still in the game.
/// - Lock is enforced elsewhere (editor/locking layer), not here.
struct ScoringEngine {
    let config: SeasonConfig
    let resultsByEpisode: [Int: EpisodeResult]

    /// Phase helper remains (unchanged signature; used elsewhere if needed)
    func phase(for episode: Episode) -> Phase {
        if episode.isMergeEpisode { return .postMerge }
        let merged = config.episodes.contains { $0.id <= episode.id && $0.isMergeEpisode }
        return merged ? .postMerge : .preMerge
    }

    /// Primary scoring function (signature unchanged for compatibility with TableView, etc.)
    func score(
        weekly: WeeklyPicks,
        episode: Episode,
        phaseOverride: PickPhase? = nil,
        categoriesById: [PickPhase.Category.ID: PickPhase.Category] = [:]
    ) -> WeeklyScoreBreakdown {

        // No results yet => no points
        guard let result = resultsByEpisode[episode.id] else {
            return WeeklyScoreBreakdown(categoryPointsByColumnId: [:])
        }

        // Build sets to know who is out
        let priorEliminations: Set<String> = resultsByEpisode
            .filter { $0.key < episode.id }
            .reduce(into: Set<String>()) { acc, entry in acc.formUnion(entry.value.votedOut) }

        let currentVotedOut = Set(result.votedOut)

        // Winner map for non-auto-score categories
        let winnersByCategory: [UUID: Set<String>] = result.categoryWinners.mapValues { Set($0) }

        // Determine which category definitions we should consider
        // Priority: phaseOverride.categories -> categoriesById fallback (keeps existing call sites working)
        let lookupCategory: (UUID) -> PickPhase.Category? = { id in
            if let c = phaseOverride?.categories.first(where: { $0.id == id }) { return c }
            return categoriesById[id]
        }

        // Active set when an override is present (only those categories score)
        let activeCategoryIds: Set<UUID>? = phaseOverride.map { Set($0.categories.map(\.id)) }

        var categoryPoints: [String: Int] = [:]

        // Union of all possibly scorables: any in active phase + any with winners if no phaseOverride
        let candidateIds: Set<UUID> = {
            if let active = activeCategoryIds { return active }
            // If no override, allow anything present in categoriesById
            return Set(categoriesById.keys)
        }()

        for categoryId in candidateIds {
            guard let category = lookupCategory(categoryId) else { continue }

            // Normalize required fields from the editor model
            let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !columnId.isEmpty else { continue } // ignore misconfigured categories

            // User's selections for this category/week
            let selections = weekly.selections(for: categoryId)
            guard !selections.isEmpty else { continue }

            if category.usesWager {
                guard let configuredWinners = winnersByCategory[categoryId], !configuredWinners.isEmpty else { continue }
                let wager = weekly.wager(for: categoryId) ?? category.wagerPoints
                guard let wager, wager > 0 else { continue }

                let hits = selections.intersection(configuredWinners)
                let delta = hits.isEmpty ? -wager : wager
                categoryPoints[columnId, default: 0] += delta
                continue
            }

            // Only "normal" scoring is supported: if pointsPerCorrectPick is nil or zero => no points.
            guard let pointsPerPick = category.pointsPerCorrectPick, pointsPerPick != 0 else { continue }

            if category.autoScoresRemainingContestants {
                // Auto-score → award points for every selection that isn't eliminated yet (prior or this week)
                let remaining = selections
                    .subtracting(priorEliminations)
                    .subtracting(currentVotedOut)

                guard !remaining.isEmpty else { continue }
                categoryPoints[columnId, default: 0] += remaining.count * pointsPerPick
            } else {
                // Normal → award for each correct winner listed for this week
                guard let winners = winnersByCategory[categoryId], !winners.isEmpty else { continue }
                let hits = selections.intersection(winners).count
                guard hits > 0 else { continue }
                categoryPoints[columnId, default: 0] += hits * pointsPerPick
            }
        }

        return WeeklyScoreBreakdown(categoryPointsByColumnId: categoryPoints)
    }
}
