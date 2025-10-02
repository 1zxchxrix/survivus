import SwiftUI

struct MergePickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let disabled = picksLocked(for: config.episodes.first)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Who Will Make the Merge (3)").font(.headline)
                if disabled { LockPill() }
            }
            LimitedMultiSelect(
                all: config.contestants,
                selection: Binding(
                    get: { app.store.seasonPicks[userId]?.mergePicks ?? [] },
                    set: { newValue in app.store.seasonPicks[userId]?.mergePicks = Set(newValue.prefix(3)) }
                ),
                max: 3,
                disabled: disabled
            )
        }
    }
}
