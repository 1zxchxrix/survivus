import SwiftUI

struct FinalThreePickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let afterMerge = config.episodes.contains(where: { $0.isMergeEpisode })
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Final Three Picks (3)").font(.headline)
                if !afterMerge {
                    Text("(Available after merge)").foregroundStyle(.secondary)
                }
            }
            LimitedMultiSelect(
                all: config.contestants,
                selection: Binding(
                    get: { app.store.seasonPicks[userId]?.finalThreePicks ?? [] },
                    set: { newValue in app.store.seasonPicks[userId]?.finalThreePicks = Set(newValue.prefix(3)) }
                ),
                max: 3,
                disabled: !afterMerge
            )
        }
    }
}
