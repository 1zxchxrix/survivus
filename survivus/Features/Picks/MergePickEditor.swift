import SwiftUI

struct MergePickEditor: View {
    @EnvironmentObject var app: AppState

    private let maxSelection = 3

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let seasonPicks = app.store.seasonPicks[userId]
        let mergeLocked = seasonPicks?.mergePicksLocked == true
        let firstEpisode = config.episodes.sorted(by: { $0.id < $1.id }).first
        let episodeLocked = firstEpisode.map { picksLocked(for: $0, userId: userId, store: app.store) } ?? false
        let disabled = mergeLocked || episodeLocked
        let contestants = app.activeContestants()
        let allowedIds = Set(contestants.map(\.id))

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if disabled {
                    if mergeLocked {
                        LockPill(text: "Locked after submission")
                    } else if let episode = firstEpisode {
                        LockPill(text: "Locked for \(episode.title)")
                    }
                } else {
                    Text("Choose up to three players you think will reach the merge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LimitedMultiSelect(
                    all: contestants,
                    selection: Binding(
                        get: {
                            let selection = app.store.seasonPicks[userId]?.mergePicks ?? []
                            return selection.intersection(allowedIds)
                        },
                        set: { newValue in
                            app.store.updateSeasonPicks(for: userId) { picks in
                                let limited = Array(newValue).prefix(maxSelection)
                                let filtered = Set(limited).intersection(allowedIds)
                                picks.mergePicks = filtered
                            }
                        }
                    ),
                    max: maxSelection,
                    disabled: disabled
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Merge Picks")
        .onAppear { pruneMergePicksIfNeeded(for: userId, isLocked: mergeLocked) }
        .onChange(of: app.store.results) { _ in pruneMergePicksIfNeeded(for: userId, isLocked: mergeLocked) }
        .onChange(of: app.store.config.contestants) { _ in pruneMergePicksIfNeeded(for: userId, isLocked: mergeLocked) }
    }

    private func pruneMergePicksIfNeeded(for userId: String, isLocked: Bool) {
        guard !isLocked else { return }
        let allowedIds = app.activeContestantIDs()
        let current = app.store.seasonPicks[userId]?.mergePicks ?? []
        let pruned = current.intersection(allowedIds)
        guard pruned != current else { return }

        app.store.updateSeasonPicks(for: userId) { picks in
            picks.mergePicks = pruned
        }
    }
}
