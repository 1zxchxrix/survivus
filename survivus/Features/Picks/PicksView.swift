import SwiftUI

struct PicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationStack {
            Form {
                Section("Season Picks") {
                    MergePickEditor()
                    FinalThreePickEditor()
                    WinnerPickEditor()
                }

                Section("Weekly Picks") {
                    Picker("Episode", selection: Binding(
                        get: { selectedEpisode?.id ?? app.store.config.episodes.first?.id ?? 1 },
                        set: { newId in selectedEpisode = app.store.config.episodes.first(where: { $0.id == newId }) }
                    )) {
                        ForEach(app.store.config.episodes) { episode in
                            Text(episode.title).tag(episode.id)
                        }
                    }
                    if let episode = app.store.config.episodes.first(where: { $0.id == (selectedEpisode?.id ?? app.store.config.episodes.first!.id) }) {
                        WeeklyPickEditor(episode: episode)
                    }
                }
            }
            .onAppear { if selectedEpisode == nil { selectedEpisode = app.store.config.episodes.first } }
            .navigationTitle("Picks")
        }
    }
}
