import Foundation

struct ScoringEngine {
    let config: SeasonConfig
    let resultsByEpisode: [Int: EpisodeResult]

    func phase(for episode: Episode) -> Phase {
        if episode.isMergeEpisode { return .postMerge }
        let merged = config.episodes.contains(where: { $0.id <= episode.id && $0.isMergeEpisode })
        return merged ? .postMerge : .preMerge
    }

    func score(weekly: WeeklyPicks, episode: Episode) -> (votedOut: Int, remain: Int, immunity: Int) {
        guard let result = resultsByEpisode[episode.id] else { return (0, 0, 0) }
        let votedOutHits = weekly.votedOut.intersection(result.votedOut).count
        let remainHits = weekly.remain.filter { !result.votedOut.contains($0) }.count
        let immunityHits = weekly.immunity.intersection(result.immunityWinners).count
        let phase = phase(for: episode)
        let immunityPts = (phase == .preMerge) ? immunityHits * 1 : immunityHits * 3
        return (votedOutHits * 3, remainHits * 1, immunityPts)
    }

    func mergeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.mergePicks.isEmpty else { return 0 }
        var pts = 0
        for ep in config.episodes where ep.id <= episodeId {
            if let res = resultsByEpisode[ep.id] {
                let alive = seasonPicks.mergePicks.subtracting(res.votedOut)
                pts += alive.count
            }
        }
        return pts
    }

    func finalThreeTrackPoints(for userId: String, upTo episodeId: Int, seasonPicks: SeasonPicks) -> Int {
        guard !seasonPicks.finalThreePicks.isEmpty else { return 0 }
        var pts = 0
        for ep in config.episodes where ep.id <= episodeId {
            if let res = resultsByEpisode[ep.id] {
                let alive = seasonPicks.finalThreePicks.subtracting(res.votedOut)
                pts += alive.count
            }
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
