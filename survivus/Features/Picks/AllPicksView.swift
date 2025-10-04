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
                            isCurrentUser: user.id == app.currentUserId,
                            selectedEpisodeId: selectedEpisode?.id
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

}

private extension AllPicksView {
    func seasonPicks(for user: UserProfile) -> SeasonPicks? {
        app.store.seasonPicks[user.id]
    }

    func weeklyPicks(for user: UserProfile) -> WeeklyPicks? {
        app.store.weeklyPicks[user.id]?[selectedWeekId]
    }

}

private struct UserPicksCard: View {
    let user: UserProfile
    let seasonPicks: SeasonPicks?
    let weeklyPicks: WeeklyPicks?
    let contestantsById: [String: Contestant]
    let isCurrentUser: Bool
    let selectedEpisodeId: Int?

    init(
        user: UserProfile,
        seasonPicks: SeasonPicks?,
        weeklyPicks: WeeklyPicks?,
        contestantsById: [String: Contestant],
        isCurrentUser: Bool,
        selectedEpisodeId: Int?
    ) {
        self.user = user
        self.seasonPicks = seasonPicks
        self.weeklyPicks = weeklyPicks
        self.contestantsById = contestantsById
        self.isCurrentUser = isCurrentUser
        self.selectedEpisodeId = selectedEpisodeId
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

            section(for: .merge, contestants: mergeContestants)
            section(for: .immunity, contestants: immunityContestants)
            section(for: .votedOut, contestants: votedOutContestants)
            section(for: .remain, contestants: remainContestants)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func section(for panel: Panel, contestants: [Contestant]) -> some View {
        if isCurrentUser, let destination = panel.destination(selectedEpisodeId: selectedEpisodeId) {
            NavigationLink(value: destination) {
                PickSection(title: panel.title, contestants: contestants, isInteractive: true)
            }
        } else {
            PickSection(title: panel.title, contestants: contestants)
        }
    }

    private enum Panel {
        case merge
        case immunity
        case votedOut
        case remain

        var title: String {
            switch self {
            case .merge:
                return "Mergers"
            case .immunity:
                return "Immunity"
            case .votedOut:
                return "Voted Out"
            case .remain:
                return "Remain"
            }
        }

        func destination(selectedEpisodeId: Int?) -> PicksDestination? {
            switch self {
            case .merge:
                return .merge
            case .immunity:
                guard let episodeId = selectedEpisodeId else { return nil }
                return .weekly(panel: .immunity, episodeId: episodeId)
            case .votedOut:
                guard let episodeId = selectedEpisodeId else { return nil }
                return .weekly(panel: .votedOut, episodeId: episodeId)
            case .remain:
                guard let episodeId = selectedEpisodeId else { return nil }
                return .weekly(panel: .remain, episodeId: episodeId)
            }
        }
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
    let isInteractive: Bool

    init(title: String, contestants: [Contestant], isInteractive: Bool = false) {
        self.title = title
        self.contestants = contestants
        self.isInteractive = isInteractive
    }

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.headline)

                Spacer()

                if isInteractive {
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
