import SwiftUI

struct PicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedEpisode: Episode?
    @State private var expandedPanel: PicksPanel? = .season(.merge)

    var body: some View {
        NavigationStack {
            Form {
                Section("Season Picks") {
                    MergePickEditor(isExpanded: binding(for: .merge))
                    FinalThreePickEditor(isExpanded: binding(for: .finalThree))
                    WinnerPickEditor(isExpanded: binding(for: .winner))
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
                        WeeklyPickEditor(episode: episode, expandedPanel: $expandedPanel)
                    }
                }
            }
            .onAppear { if selectedEpisode == nil { selectedEpisode = app.store.config.episodes.first } }
            .navigationTitle("Picks")
        }
    }

    private func binding(for panel: SeasonPickPanel) -> Binding<Bool> {
        binding(for: .season(panel))
    }

    private func binding(for panel: PicksPanel) -> Binding<Bool> {
        Binding(
            get: { expandedPanel == panel },
            set: { newValue in
                expandedPanel = newValue ? panel : nil
            }
        )
    }
}
