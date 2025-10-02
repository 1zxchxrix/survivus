import SwiftUI

struct FinalThreePickEditor: View {
    @EnvironmentObject var app: AppState

    private let maxSelection = 3

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let afterMerge = config.episodes.contains(where: { $0.isMergeEpisode })

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
                    all: config.contestants,
                    selection: Binding(
                        get: { app.store.seasonPicks[userId]?.finalThreePicks ?? [] },
                        set: { newValue in app.store.seasonPicks[userId]?.finalThreePicks = Set(newValue.prefix(maxSelection)) }
                    ),
                    max: maxSelection,
                    disabled: !afterMerge
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Final Three Picks")
    }
}
