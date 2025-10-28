import SwiftUI

struct WinnerPickEditor: View {
    @EnvironmentObject var app: AppState
    @Environment(\.votedOutContestantIDs) private var votedOutContestantIDs

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let enable = config.episodes.count >= 2
        let eligibleContestants = config.contestants.filter { !votedOutContestantIDs.contains($0.id) }

        Form {
            Section {
                Picker("Winner", selection: Binding(
                    get: { app.store.seasonPicks[userId]?.winnerPick ?? "" },
                    set: { newValue in
                        app.store.updateSeasonPicks(for: userId) { picks in
                            picks.winnerPick = newValue.isEmpty ? nil : newValue
                        }
                    }
                )) {
                    Text("—").tag("")
                    ForEach(eligibleContestants) { contestant in
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
        .onChange(of: votedOutContestantIDs) { eliminated in
            guard let current = app.store.seasonPicks[userId]?.winnerPick,
                  eliminated.contains(current) else { return }
            app.store.updateSeasonPicks(for: userId) { picks in
                picks.winnerPick = nil
            }
        }
    }
}
