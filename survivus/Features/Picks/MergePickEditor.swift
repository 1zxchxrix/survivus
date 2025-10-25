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
        let episodeLocked = firstEpisode.map { picksLocked(for: $0) } ?? false
        let disabled = mergeLocked || episodeLocked

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
                    all: config.contestants,
                    selection: Binding(
                        get: { app.store.seasonPicks[userId]?.mergePicks ?? [] },
                        set: { newValue in
                            app.store.updateSeasonPicks(for: userId) { picks in
                                picks.mergePicks = Set(newValue.prefix(maxSelection))
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
    }
}
