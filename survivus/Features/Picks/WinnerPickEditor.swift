import SwiftUI

struct WinnerPickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let enable = config.episodes.count >= 2
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sole Survivor (1)").font(.headline)
                if !enable {
                    Text("(Available after Final Three)").foregroundStyle(.secondary)
                }
            }
            Picker("Winner", selection: Binding(
                get: { app.store.seasonPicks[userId]?.winnerPick ?? "" },
                set: { app.store.seasonPicks[userId]?.winnerPick = $0.isEmpty ? nil : $0 }
            )) {
                Text("—").tag("")
                ForEach(app.store.config.contestants) { contestant in
                    Text(contestant.name).tag(contestant.id)
                }
            }
            .disabled(!enable)
        }
    }
}
