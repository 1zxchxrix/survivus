import SwiftUI

struct WinnerPickEditor: View {
    @EnvironmentObject var app: AppState
    @Binding var isExpanded: Bool

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let enable = config.episodes.count >= 2
        DisclosureGroup(isExpanded: $isExpanded) {
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
            .padding(.top, 4)
        } label: {
            HStack {
                Text("Sole Survivor (1)")
                    .font(.headline)
                if !enable {
                    Text("(Available after Final Three)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
