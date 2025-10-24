import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var app: AppState

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    private var displayedEpisodes: [Episode] {
        let configuredEpisodes = Dictionary(uniqueKeysWithValues: app.store.config.episodes.map { ($0.id, $0) })
        return app.store.results
            .compactMap { result in
                configuredEpisodes[result.id] ?? Episode(id: result.id)
            }
            .sorted(by: { lhs, rhs in
                let lhsDate = lhs.airDate ?? .distantPast
                let rhsDate = rhs.airDate ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.id > rhs.id
                }
                return lhsDate > rhsDate
            })
    }

    var body: some View {
        NavigationStack {
            List(displayedEpisodes) { episode in
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
                        if let airDate = episode.airDate {
                            Text(airDate, style: .date).foregroundStyle(.secondary)
                        }
                    }
                    if let result {
                        let immunityContestants = contestants(for: result.immunityWinners)
                        let votedOutContestants = contestants(for: result.votedOut)
                        if !immunityContestants.isEmpty {
                            ContestantResultRow(title: "Immunity", contestants: immunityContestants)
                        }
                        if !votedOutContestants.isEmpty {
                            ContestantResultRow(title: "Voted out", contestants: votedOutContestants)
                        }
                    } else {
                        Text("No result yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Results")
        }
    }

    private func contestants(for ids: [String]) -> [Contestant] {
        ids.compactMap { contestantsById[$0] }
    }
}

private struct ContestantResultRow: View {
    let title: String
    let contestants: [Contestant]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(contestants) { contestant in
                ContestantNameLabel(contestant: contestant, avatarSize: 22, font: .subheadline)
            }
        }
        .padding(.top, 2)
    }
}
