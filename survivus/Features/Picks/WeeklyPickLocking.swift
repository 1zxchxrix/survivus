import Foundation

extension AppState {
    func applyLockedSelections(for userId: String, picks: inout WeeklyPicks) -> Bool {
        guard let context = phaseContext(forEpisodeId: picks.episodeId) else { return false }

        var didChange = false

        for category in context.phase.categories where category.isLocked {
            guard let lockedSelection = lockedSelections(for: category, phaseId: context.phaseId, userId: userId) else {
                continue
            }

            let current = selections(for: category, in: picks)
            if current != lockedSelection {
                setSelections(lockedSelection, for: category, in: &picks)
                didChange = true
            }
        }

        return didChange
    }

    func phaseContext(forEpisodeId episodeId: Int) -> (phase: PickPhase, phaseId: PickPhase.ID)? {
        if let result = store.resultsByEpisode[episodeId],
           let phaseId = result.phaseId,
           let phase = phases.first(where: { $0.id == phaseId }) {
            return (phase, phaseId)
        }

        if let activePhase = activePhase {
            return (activePhase, activePhase.id)
        }

        return nil
    }

    func phaseEpisodeIds(for phaseId: PickPhase.ID) -> [Int] {
        store.results
            .filter { $0.phaseId == phaseId }
            .map(\.id)
            .sorted()
    }

    func selections(for category: PickPhase.Category, in picks: WeeklyPicks) -> Set<String> {
        picks.selections(for: category.id)
    }

    func setSelections(_ selections: Set<String>, for category: PickPhase.Category, in picks: inout WeeklyPicks) {
        picks.setSelections(selections, for: category.id)
    }

    private func lockedSelections(
        for category: PickPhase.Category,
        phaseId: PickPhase.ID,
        userId: String
    ) -> Set<String>? {
        guard let picksByEpisode = store.weeklyPicks[userId] else { return nil }

        let episodeIds = phaseEpisodeIds(for: phaseId)
        for episodeId in episodeIds {
            guard let picks = picksByEpisode[episodeId] else { continue }
            let selection = selections(for: category, in: picks)
            if !selection.isEmpty {
                return selection
            }
        }

        return nil
    }
}
