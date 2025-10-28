import SwiftUI

struct WinnerPickEditor: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let enable = config.episodes.count >= 2
        let contestants = app.activeContestants()
        let allowedIds = Set(contestants.map(\.id))

        Form {
            Section {
                Picker("Winner", selection: Binding(
                    get: {
                        let current = app.store.seasonPicks[userId]?.winnerPick ?? ""
                        return allowedIds.contains(current) ? current : ""
                    },
                    set: { newValue in
                        app.store.updateSeasonPicks(for: userId) { picks in
                            let value = allowedIds.contains(newValue) ? newValue : ""
                            picks.winnerPick = value.isEmpty ? nil : value
                        }
                    }
                )) {
                    Text("—").tag("")
                    ForEach(contestants) { contestant in
                        Text(contestant.name).tag(contestant.id)
                    }
                }
                .pickerStyle(.wheel)
                .disabled(!enable)
            } footer: {
                if !enable {
                    Text("Winner picks unlock once the Final Three is determined.")
                }
            }
        }
        .navigationTitle("Sole Survivor")
        .onAppear { pruneWinnerPickIfNeeded(for: userId) }
        .onChange(of: app.store.results) { _ in pruneWinnerPickIfNeeded(for: userId) }
        .onChange(of: app.store.config.contestants) { _ in pruneWinnerPickIfNeeded(for: userId) }
    }

    private func pruneWinnerPickIfNeeded(for userId: String) {
        let allowedIds = app.activeContestantIDs()
        guard let current = app.store.seasonPicks[userId]?.winnerPick, !current.isEmpty else { return }
        guard !allowedIds.contains(current) else { return }

        app.store.updateSeasonPicks(for: userId) { picks in
            if let winner = picks.winnerPick, !allowedIds.contains(winner) {
                picks.winnerPick = nil
            }
        }
    }
}
