import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List(app.store.config.episodes) { episode in
                let result = app.store.resultsByEpisode[episode.id]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(episode.title).font(.headline)
                        if episode.isMergeEpisode {
                            Text("MERGE")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.yellow.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Spacer()
                        Text(episode.airDate, style: .date).foregroundStyle(.secondary)
                    }
                    if let result {
                        if !result.immunityWinners.isEmpty {
                            Text("Immunity: " + result.immunityWinners.compactMap { id in
                                app.store.config.contestants.first { $0.id == id }?.name
                            }.joined(separator: ", "))
                        }
                        if !result.votedOut.isEmpty {
                            Text("Voted out: " + result.votedOut.compactMap { id in
                                app.store.config.contestants.first { $0.id == id }?.name
                            }.joined(separator: ", "))
                        }
                    } else {
                        Text("No result yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Results")
        }
    }
}
