import SwiftUI

private enum PicksDestination: Hashable {
    case merge
    case weekly(panel: WeeklyPickPanel, episodeId: Int)
}

struct AllPicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedWeekId: Int = 1
    @State private var navigationPath = NavigationPath()

    private var weekOptions: [WeekOption] {
        app.store.config.episodes
            .filter { $0.id <= 2 }
            .map { WeekOption(id: $0.id, title: $0.title) }
            .sorted { $0.id < $1.id }
    }

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    private var selectedEpisode: Episode? {
        app.store.config.episodes.first(where: { $0.id == selectedWeekId })
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weekPicker
                        .padding(.bottom, 8)

                    ForEach(app.store.users) { user in
                        UserPicksCard(
                            user: user,
                            seasonPicks: seasonPicks(for: user),
                            weeklyPicks: weeklyPicks(for: user),
                            contestantsById: contestantsById,
                            onMergeTap: mergeAction(for: user),
                            onImmunityTap: weeklyAction(for: user, panel: .immunity),
                            onVotedOutTap: weeklyAction(for: user, panel: .votedOut),
                            onRemainTap: weeklyAction(for: user, panel: .remain)
                        )
                    }
                }
                .padding()
            }
            .onAppear {
                if let firstWeek = weekOptions.first {
                    selectedWeekId = firstWeek.id
                }
            }
            .navigationTitle("Picks")
        }
        .navigationDestination(for: PicksDestination.self) { destination in
            switch destination {
            case .merge:
                MergePickEditor()
            case let .weekly(panel, episodeId):
                if let episode = app.store.config.episodes.first(where: { $0.id == episodeId }) {
                    WeeklyPickEditor(episode: episode, panel: panel)
                } else {
                    Text("Episode not found")
                }
            }
        }
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Picker("Week", selection: $selectedWeekId) {
                ForEach(weekOptions) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .pickerStyle(.menu)
        }
}

    @ViewBuilder
    private func userCard(for user: UserProfile) -> some View {
        let seasonPicks = app.store.seasonPicks[user.id]
        let weeklyPicks = app.store.weeklyPicks[user.id]?[selectedWeekId]
        let isCurrentUser = user.id == app.currentUserId

        let mergeTap: (() -> Void)? = isCurrentUser ? {
            navigationPath.append(PicksDestination.merge)
        } : nil

        let immunityTap: (() -> Void)? = isCurrentUser ? {
            if let episode = selectedEpisode {
                navigationPath.append(PicksDestination.weekly(panel: .immunity, episodeId: episode.id))
            }
        } : nil

        let votedOutTap: (() -> Void)? = isCurrentUser ? {
            if let episode = selectedEpisode {
                navigationPath.append(PicksDestination.weekly(panel: .votedOut, episodeId: episode.id))
            }
        } : nil

        let remainTap: (() -> Void)? = isCurrentUser ? {
            if let episode = selectedEpisode {
                navigationPath.append(PicksDestination.weekly(panel: .remain, episodeId: episode.id))
            }
        } : nil

        UserPicksCard(
            user: user,
            seasonPicks: seasonPicks,
            weeklyPicks: weeklyPicks,
            contestantsById: contestantsById,
            onMergeTap: mergeTap,
            onImmunityTap: immunityTap,
            onVotedOutTap: votedOutTap,
            onRemainTap: remainTap
        )
    }
}

private extension AllPicksView {
    func seasonPicks(for user: UserProfile) -> SeasonPicks? {
        app.store.seasonPicks[user.id]
    }

    func weeklyPicks(for user: UserProfile) -> WeeklyPicks? {
        app.store.weeklyPicks[user.id]?[selectedWeekId]
    }

    func mergeAction(for user: UserProfile) -> (() -> Void)? {
        guard user.id == app.currentUserId else { return nil }
        return {
            self.navigationPath.append(PicksDestination.merge)
        }
    }

    func weeklyAction(for user: UserProfile, panel: WeeklyPickPanel) -> (() -> Void)? {
        guard user.id == app.currentUserId else { return nil }
        return {
            if let episode = self.selectedEpisode {
                self.navigationPath.append(PicksDestination.weekly(panel: panel, episodeId: episode.id))
            }
        }
    }
}

private struct UserPicksCard: View {
    let user: UserProfile
    let seasonPicks: SeasonPicks?
    let weeklyPicks: WeeklyPicks?
    let contestantsById: [String: Contestant]
    let onMergeTap: (() -> Void)?
    let onImmunityTap: (() -> Void)?
    let onVotedOutTap: (() -> Void)?
    let onRemainTap: (() -> Void)?

    init(
        user: UserProfile,
        seasonPicks: SeasonPicks?,
        weeklyPicks: WeeklyPicks?,
        contestantsById: [String: Contestant],
        onMergeTap: (() -> Void)? = nil,
        onImmunityTap: (() -> Void)? = nil,
        onVotedOutTap: (() -> Void)? = nil,
        onRemainTap: (() -> Void)? = nil
    ) {
        self.user = user
        self.seasonPicks = seasonPicks
        self.weeklyPicks = weeklyPicks
        self.contestantsById = contestantsById
        self.onMergeTap = onMergeTap
        self.onImmunityTap = onImmunityTap
        self.onVotedOutTap = onVotedOutTap
        self.onRemainTap = onRemainTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(user.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            let mergeContestants = contestants(
                for: seasonPicks?.mergePicks ?? Set<String>(),
                limit: 3
            )
            let immunityContestants = contestants(
                for: weeklyPicks?.immunity ?? Set<String>(),
                limit: 3
            )
            let votedOutContestants = contestants(
                for: weeklyPicks?.votedOut ?? Set<String>(),
                limit: 3
            )
            let remainContestants = contestants(
                for: weeklyPicks?.remain ?? Set<String>(),
                limit: 3,
                excluding: weeklyPicks?.votedOut ?? Set<String>()
            )

            PickSection(
                title: "Mergers",
                contestants: mergeContestants,
                onTap: onMergeTap
            )

            PickSection(
                title: "Immunity",
                contestants: immunityContestants,
                onTap: onImmunityTap
            )

            PickSection(
                title: "Voted Out",
                contestants: votedOutContestants,
                onTap: onVotedOutTap
            )

            PickSection(
                title: "Remain",
                contestants: remainContestants,
                onTap: onRemainTap
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func contestants(
        for ids: Set<String>,
        limit: Int? = nil,
        excluding excludedIds: Set<String> = Set<String>()
    ) -> [Contestant] {
        let filteredIds = ids.subtracting(excludedIds)
        let picks = filteredIds.compactMap { contestantsById[$0] }
            .sorted { $0.name < $1.name }
        if let limit {
            return Array(picks.prefix(limit))
        }
        return picks
    }
}

private struct PickSection: View {
    let title: String
    let contestants: [Contestant]
    let onTap: (() -> Void)?

    init(title: String, contestants: [Contestant], onTap: (() -> Void)? = nil) {
        self.title = title
        self.contestants = contestants
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.headline)

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if contestants.isEmpty {
                Text("No picks yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(contestants) { contestant in
                        VStack(spacing: 8) {
                            ContestantAvatar(imageName: contestant.id, size: 60)

                            Text(contestant.name)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(contestant.name)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct WeekOption: Identifiable {
    let id: Int
    let title: String
}

#Preview {
    AllPicksView()
        .environmentObject(AppState())
}
