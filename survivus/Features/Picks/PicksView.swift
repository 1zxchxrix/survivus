import SwiftUI

struct PicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationStack {
            Form {
                seasonSection
                weeklySection
            }
            .onAppear { if selectedEpisode == nil { selectedEpisode = app.store.config.episodes.first } }
            .navigationTitle("Your Picks")
        }
    }

    private var seasonSection: some View {
        Section("Season Picks") {
            let config = app.store.config
            let userId = app.currentUserId
            let seasonPicks = app.store.seasonPicks[userId] ?? SeasonPicks(userId: userId)
            let mergeLocked = picksLocked(for: config.episodes.first)
            let mergeContestants = contestants(for: seasonPicks.mergePicks)

            NavigationLink {
                MergePickEditor()
            } label: {
                PickSummaryRow(
                    title: "Who Will Make the Merge (3)",
                    contestants: mergeContestants,
                    placeholder: "Select up to 3 players"
                ) {
                    if mergeLocked { LockPill() }
                }
            }

            let afterMerge = config.episodes.contains { $0.isMergeEpisode }
            NavigationLink {
                FinalThreePickEditor()
            } label: {
                PickSummaryRow(
                    title: "Final Three Picks (3)",
                    subtitle: afterMerge ? nil : "Unlocks after the merge episode airs.",
                    contestants: contestants(for: seasonPicks.finalThreePicks),
                    placeholder: "Select up to 3 players"
                ) {
                    if !afterMerge { LockPill(text: "Locked") }
                }
            }

            let winnerAvailable = config.episodes.count >= 2
            NavigationLink {
                WinnerPickEditor()
            } label: {
                let winnerContestants = seasonPicks.winnerPick.flatMap { contestantsById[$0] }.map { [$0] } ?? []
                PickSummaryRow(
                    title: "Sole Survivor (1)",
                    subtitle: winnerAvailable ? nil : "Unlocks after Final Three picks.",
                    contestants: winnerContestants,
                    placeholder: "Select your winner"
                ) {
                    if !winnerAvailable { LockPill(text: "Locked") }
                }
            }
        }
    }

    private var weeklySection: some View {
        Section("Weekly Picks") {
            HStack(alignment: .firstTextBaseline) {
                Picker("Episode", selection: Binding(
                    get: { selectedEpisode?.id ?? app.store.config.episodes.first?.id ?? 1 },
                    set: { newId in selectedEpisode = app.store.config.episodes.first(where: { $0.id == newId }) }
                )) {
                    ForEach(app.store.config.episodes) { episode in
                        Text(episode.title).tag(episode.id)
                    }
                }

                Spacer()

                NavigationLink {
                    AdminRoomView()
                } label: {
                    Image(systemName: "door.left.hand.open")
                        .imageScale(.large)
                        .padding(.leading, 8)
                        .accessibilityLabel("Admin Room")
                }
            }

            if let episode = selectedEpisode ?? app.store.config.episodes.first {
                let userId = app.currentUserId
                let weekly = app.store.weeklyPicks[userId]?[episode.id] ?? WeeklyPicks(userId: userId, episodeId: episode.id)
                let locked = picksLocked(for: episode)
                let phase = app.scoring.phase(for: episode)
                let caps = (phase == .preMerge) ? app.store.config.weeklyPickCapsPreMerge : app.store.config.weeklyPickCapsPostMerge
                let remainCap = caps.remain ?? 3
                let votedOutCap = caps.votedOut ?? 3
                let immunityCap = caps.immunity ?? 3

                NavigationLink {
                    WeeklyPickEditor(episode: episode, panel: .remain)
                } label: {
                    PickSummaryRow(
                        title: "Who Will Remain (\(remainCap))",
                        contestants: contestants(for: weekly.remain),
                        placeholder: placeholder(limit: remainCap, noun: "player")
                    ) {
                        if locked { LockPill() }
                    }
                }

                NavigationLink {
                    WeeklyPickEditor(episode: episode, panel: .votedOut)
                } label: {
                    PickSummaryRow(
                        title: "Who Will be Voted Out (\(votedOutCap))",
                        contestants: contestants(for: weekly.votedOut),
                        placeholder: placeholder(limit: votedOutCap, noun: "player")
                    ) {
                        if locked { LockPill() }
                    }
                }

                NavigationLink {
                    WeeklyPickEditor(episode: episode, panel: .immunity)
                } label: {
                    PickSummaryRow(
                        title: "Who Will Have Immunity (\(immunityCap))",
                        contestants: contestants(for: weekly.immunity),
                        placeholder: placeholder(limit: immunityCap, noun: "player")
                    ) {
                        if locked { LockPill() }
                    }
                }
            }
        }
    }

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    private func contestants(for ids: Set<String>) -> [Contestant] {
        ids.compactMap { contestantsById[$0] }
            .sorted { $0.name < $1.name }
    }

    private func placeholder(limit: Int, noun: String) -> String {
        if limit <= 1 {
            return "Select 1 \(noun)"
        }
        return "Select up to \(limit) \(noun)s"
    }
}

private struct PickSummaryRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let contestants: [Contestant]
    let placeholder: String
    @ViewBuilder var accessory: () -> Accessory

    init(
        title: String,
        subtitle: String? = nil,
        contestants: [Contestant],
        placeholder: String,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.contestants = contestants
        self.placeholder = placeholder
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                accessory()
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if contestants.isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(contestants.map { $0.name }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

extension PickSummaryRow where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        contestants: [Contestant],
        placeholder: String
    ) {
        self.init(title: title, subtitle: subtitle, contestants: contestants, placeholder: placeholder) {
            EmptyView()
        }
    }
}
