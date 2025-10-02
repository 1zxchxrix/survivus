import SwiftUI

struct PicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedEpisode: Episode?
    @State private var expandedSeasonPick: SeasonPickPanel? = .merge
    @State private var expandedWeeklyPick: WeeklyPickPanel?

    var body: some View {
        NavigationStack {
            Form {
                Section("Season Picks") {
                    MergePickEditor(isExpanded: seasonBinding(for: .merge))
                    FinalThreePickEditor(isExpanded: seasonBinding(for: .finalThree))
                    WinnerPickEditor(isExpanded: seasonBinding(for: .winner))
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
                        WeeklyPickEditor(
                            episode: episode,
                            expandedPanel: $expandedWeeklyPick,
                            collapseSeasonPanels: { expandedSeasonPick = nil }
                        )
                    }
                }
            }
            .onAppear { if selectedEpisode == nil { selectedEpisode = app.store.config.episodes.first } }
            .navigationTitle("Picks")
        }
    }

    private func seasonBinding(for panel: SeasonPickPanel) -> Binding<Bool> {
        Binding(
            get: { expandedSeasonPick == panel },
            set: { newValue in
                if newValue {
                    expandedWeeklyPick = nil
                    expandedSeasonPick = panel
                } else if expandedSeasonPick == panel {
                    expandedSeasonPick = nil
                }
            }
        )
    }

}

private enum SeasonPickPanel: Hashable {
    case merge
    case finalThree
    case winner
}
