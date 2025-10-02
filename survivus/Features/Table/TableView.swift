import SwiftUI

struct TableView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        let config = app.store.config
        let scoring = app.scoring
        let lastEpisodeWithResult = app.store.results.map { $0.id }.max() ?? 0
        let usersById = Dictionary(uniqueKeysWithValues: app.store.users.map { ($0.id, $0) })

        let breakdowns: [UserScoreBreakdown] = app.store.users.map { user in
            var votedOutPoints = 0
            var remainPoints = 0
            var immunityPoints = 0
            var weeksParticipated = 0

            for episode in config.episodes where episode.id <= lastEpisodeWithResult {
                if let picks = app.store.weeklyPicks[user.id]?[episode.id] {
                    weeksParticipated += 1
                    let score = scoring.score(weekly: picks, episode: episode)
                    votedOutPoints += score.votedOut
                    remainPoints += score.remain
                    immunityPoints += score.immunity
                }
            }

            let season = app.store.seasonPicks[user.id] ?? SeasonPicks(userId: user.id)
            let mergePoints = scoring.mergeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let finalThreePoints = scoring.finalThreeTrackPoints(for: user.id, upTo: lastEpisodeWithResult, seasonPicks: season)
            let winnerPoints = scoring.winnerPoints(seasonPicks: season, finalResult: nil)

            return UserScoreBreakdown(
                userId: user.id,
                weeksParticipated: weeksParticipated,
                votedOutPoints: votedOutPoints,
                remainPoints: remainPoints,
                immunityPoints: immunityPoints,
                mergeTrackPoints: mergePoints,
                finalThreeTrackPoints: finalThreePoints,
                winnerPoints: winnerPoints
            )
        }
        .sorted { $0.total > $1.total }

        return NavigationStack {
            List {
                TableHeader()
                ForEach(breakdowns) { breakdown in
                    HStack(spacing: 12) {
                        if let user = usersById[breakdown.userId] {
                            Image(user.avatarAssetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .accessibilityHidden(true)
                            Text(user.displayName)
                        } else {
                            Text(breakdown.userId)
                        }
                        Spacer()
                        Text("\(breakdown.weeksParticipated)").frame(width: 32)
                        Text("\(breakdown.votedOutPoints)").frame(width: 40)
                        Text("\(breakdown.remainPoints)").frame(width: 40)
                        Text("\(breakdown.immunityPoints)").frame(width: 40)
                        Text("\(breakdown.total)").fontWeight(.semibold).frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("Table")
        }
    }
}

struct TableHeader: View {
    var body: some View {
        HStack {
            Text("Name").fontWeight(.semibold)
            Spacer()
            Text("Wk").frame(width: 32)
            Text("VO").frame(width: 40)
            Text("RM").frame(width: 40)
            Text("IM").frame(width: 40)
            Text("Total").frame(width: 50, alignment: .trailing)
        }
        .foregroundStyle(.secondary)
    }
}
