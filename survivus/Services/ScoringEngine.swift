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
    let phasesById: [PickPhase.ID: PickPhase]

    init(
        config: SeasonConfig,
        resultsByEpisode: [Int: EpisodeResult],
        phasesById: [PickPhase.ID: PickPhase] = [:]
    ) {
        self.config = config
        self.resultsByEpisode = resultsByEpisode
        self.phasesById = phasesById
    }

    func phase(for episode: Episode) -> Phase {
        if let phase = pickPhase(for: episode) {
            let name = phase.name
            if name.range(of: "post", options: .caseInsensitive) != nil,
               name.range(of: "merge", options: .caseInsensitive) != nil {
                return .postMerge
            }
            if name.range(of: "pre", options: .caseInsensitive) != nil,
               name.range(of: "merge", options: .caseInsensitive) != nil {
                return .preMerge
            }
        }
        if episode.isMergeEpisode { return .postMerge }
        let merged = config.episodes.contains(where: { $0.id <= episode.id && $0.isMergeEpisode })
        return merged ? .postMerge : .preMerge
    }

    func score(
        weekly: WeeklyPicks,
        episode: Episode,
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
        let standardPoints = standardPoints(for: episode, result: result)
        let votedOutPoints = standardPoints.votedOut > 0 ? votedOutHits * standardPoints.votedOut : 0
        let remainPoints = standardPoints.remain > 0 ? remainHits * standardPoints.remain : 0
        let immunityPts = standardPoints.immunity > 0 ? immunityHits * standardPoints.immunity : 0
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

    func standardPoints(for episode: Episode) -> (remain: Int, votedOut: Int, immunity: Int) {
        let result = resultsByEpisode[episode.id]
        return standardPoints(for: episode, result: result)
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
    func pickPhase(for episode: Episode) -> PickPhase? {
        guard let phaseId = resultsByEpisode[episode.id]?.phaseId else { return nil }
        return phasesById[phaseId]
    }

    func standardPoints(for episode: Episode, result: EpisodeResult?) -> (remain: Int, votedOut: Int, immunity: Int) {
        let fallback = fallbackStandardPoints(for: phase(for: episode))
        guard
            let result,
            let phaseId = result.phaseId,
            let phase = phasesById[phaseId]
        else {
            return fallback
        }

        let remain = resolvedPoints(in: phase, matching: { $0.matchesRemainCategory }, defaultValue: fallback.remain)
        let votedOut = resolvedPoints(in: phase, matching: { $0.matchesVotedOutCategory }, defaultValue: fallback.votedOut)
        let immunity = resolvedPoints(in: phase, matching: { $0.matchesImmunityCategory }, defaultValue: fallback.immunity)

        return (remain, votedOut, immunity)
    }

    func resolvedPoints(in phase: PickPhase, matching predicate: (PickPhase.Category) -> Bool, defaultValue: Int) -> Int {
        guard let category = phase.categories.first(where: predicate),
              let points = category.pointsPerCorrectPick,
              points > 0
        else {
            return defaultValue
        }
        return points
    }

    func fallbackStandardPoints(for phase: Phase) -> (remain: Int, votedOut: Int, immunity: Int) {
        let immunity = phase == .preMerge ? 1 : 3
        return (remain: 1, votedOut: 3, immunity: immunity)
    }

    func episodeIds(upTo upperBound: Int) -> [Int] {
        var idSet = Set(config.episodes.map(\.id))
        idSet.formUnion(resultsByEpisode.keys)

        return idSet
            .filter { $0 <= upperBound }
            .sorted()
    }
}
