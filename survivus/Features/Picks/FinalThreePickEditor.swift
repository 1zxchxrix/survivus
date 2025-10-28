import SwiftUI

struct FinalThreePickEditor: View {
    @EnvironmentObject var app: AppState

    private let maxSelection = 3

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let afterMerge = config.episodes.contains(where: { $0.isMergeEpisode })
        let contestants = app.activeContestants()
        let allowedIds = Set(contestants.map(\.id))

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if afterMerge {
                    Text("Lock in your final three finalists.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LockPill(text: "Available after merge")
                }

                LimitedMultiSelect(
                    all: contestants,
                    selection: Binding(
                        get: {
                            let selection = app.store.seasonPicks[userId]?.finalThreePicks ?? []
                            return selection.intersection(allowedIds)
                        },
                        set: { newValue in
                            app.store.updateSeasonPicks(for: userId) { picks in
                                let limited = Array(newValue).prefix(maxSelection)
                                let filtered = Set(limited).intersection(allowedIds)
                                picks.finalThreePicks = filtered
                            }
                        }
                    ),
                    max: maxSelection,
                    disabled: !afterMerge
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Final Three Picks")
        .onAppear { pruneFinalThreePicksIfNeeded(for: userId) }
        .onChange(of: app.store.results) { _ in pruneFinalThreePicksIfNeeded(for: userId) }
        .onChange(of: app.store.config.contestants) { _ in pruneFinalThreePicksIfNeeded(for: userId) }
    }

    private func pruneFinalThreePicksIfNeeded(for userId: String) {
        let allowedIds = app.activeContestantIDs()
        let current = app.store.seasonPicks[userId]?.finalThreePicks ?? []
        let pruned = current.intersection(allowedIds)
        guard pruned != current else { return }

        app.store.updateSeasonPicks(for: userId) { picks in
            picks.finalThreePicks = pruned
        }
    }
}
