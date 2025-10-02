import SwiftUI

struct MergePickEditor: View {
    @EnvironmentObject var app: AppState

    private let maxSelection = 3

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let disabled = picksLocked(for: config.episodes.first)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if disabled {
                    LockPill(text: "Locked for \(config.episodes.first?.title ?? "Episode")")
                } else {
                    Text("Choose up to three players you think will reach the merge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { app.store.seasonPicks[userId]?.mergePicks ?? [] },
                        set: { newValue in app.store.seasonPicks[userId]?.mergePicks = Set(newValue.prefix(maxSelection)) }
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
