import SwiftUI

struct AllPicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedWeek: WeekSelection = .none
    @State private var knownWeekIds: Set<Int> = []

    private var weekOptions: [WeekOption] {
        let weeklyEpisodeIds = app.store.weeklyPicks.values.flatMap { $0.keys }
        let startedEpisodeIds = app.store.results.map(\.id)
        let availableEpisodeIds = Set(weeklyEpisodeIds).union(startedEpisodeIds)

        guard !availableEpisodeIds.isEmpty else {
            return [WeekOption(selection: .none, title: "None")]
        }

        let episodesById = Dictionary(uniqueKeysWithValues: app.store.config.episodes.map { ($0.id, $0) })
        let episodeOptions = availableEpisodeIds
            .sorted()
            .compactMap { episodeId -> WeekOption? in
                guard let episode = episodesById[episodeId] else {
                    return WeekOption(selection: .week(episodeId), title: "Week \(episodeId)")
                }

                return WeekOption(selection: .week(episode.id), title: episode.title)
            }

        return [WeekOption(selection: .none, title: "None")] + episodeOptions
    }

    private var availableWeekSelections: Set<WeekSelection> {
        Set(weekOptions.map(\.selection))
    }

    private var contestantsById: [String: Contestant] {
        Dictionary(uniqueKeysWithValues: app.store.config.contestants.map { ($0.id, $0) })
    }

    private var activePhaseCategories: [PickPhase.Category] {
        activePhase?.categories ?? []
    }

    private var hasConfiguredPickData: Bool {
        guard let activePhase else { return false }
        return !activePhase.categories.isEmpty
    }

    private var activePhase: PickPhase? {
        app.activePhase
    }

    private var selectedEpisode: Episode? {
        guard case let .week(episodeId) = selectedWeek else { return nil }
        return app.store.config.episodes.first(where: { $0.id == episodeId })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if hasConfiguredPickData {
                        weekPicker
                            .padding(.bottom, 8)

                        ForEach(app.store.users) { user in
                            UserPicksCard(
                                user: user,
                                seasonPicks: seasonPicks(for: user),
                                weeklyPicks: weeklyPicks(for: user),
                                contestantsById: contestantsById,
                                isCurrentUser: user.id == app.currentUserId,
                                selectedEpisode: selectedEpisode,
                                categories: activePhaseCategories
                            )
                        }
                    } else {
                        VStack(spacing: 24) {
                            ContentUnavailableView(
                                "No pick categories",
                                systemImage: "square.grid.3x3",
                                description: Text("Check back once phases and pick categories have been created.")
                            )
                            NavigationLink {
                                AdminRoomView()
                            } label: {
                                Label("Open Admin Room", systemImage: "door.left.hand.open")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Picks")
        }
        .onAppear {
            updateSelectedWeek(with: availableWeekSelections)
        }
        .onChange(of: availableWeekSelections) { selections in
            updateSelectedWeek(with: selections)
        }
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline) {
                Picker("Week", selection: $selectedWeek) {
                    ForEach(weekOptions) { option in
                        Text(option.title)
                            .tag(option.selection)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                NavigationLink {
                    AdminRoomView()
                } label: {
                    Image(systemName: "door.left.hand.open")
                        .imageScale(.large)
                        .padding(.trailing, 10)
                        .accessibilityLabel("Admin Room")
                }
            }
            
        }
}

}

private extension AllPicksView {
    func updateSelectedWeek(with selections: Set<WeekSelection>) {
        let weekIds = Set(selections.compactMap { $0.weekId })

        defer { knownWeekIds = weekIds }

        guard !weekIds.isEmpty else {
            selectedWeek = .none
            return
        }

        let newlyAddedWeeks = weekIds.subtracting(knownWeekIds)

        if let newestWeek = newlyAddedWeeks.max() {
            selectedWeek = .week(newestWeek)
            return
        }

        if let currentWeekId = selectedWeek.weekId, weekIds.contains(currentWeekId) {
            return
        }

        if let latestWeek = weekIds.max() {
            selectedWeek = .week(latestWeek)
        } else {
            selectedWeek = .none
        }
    }

    func seasonPicks(for user: UserProfile) -> SeasonPicks? {
        app.store.seasonPicks[user.id]
    }

    func weeklyPicks(for user: UserProfile) -> WeeklyPicks? {
        guard case let .week(episodeId) = selectedWeek else { return nil }
        return app.store.weeklyPicks[user.id]?[episodeId]
    }

}

private struct UserPicksCard: View {
    let user: UserProfile
    let seasonPicks: SeasonPicks?
    let weeklyPicks: WeeklyPicks?
    let contestantsById: [String: Contestant]
    let isCurrentUser: Bool
    let selectedEpisode: Episode?
    let categories: [PickPhase.Category]

    init(
        user: UserProfile,
        seasonPicks: SeasonPicks?,
        weeklyPicks: WeeklyPicks?,
        contestantsById: [String: Contestant],
        isCurrentUser: Bool,
        selectedEpisode: Episode?,
        categories: [PickPhase.Category]
    ) {
        self.user = user
        self.seasonPicks = seasonPicks
        self.weeklyPicks = weeklyPicks
        self.contestantsById = contestantsById
        self.isCurrentUser = isCurrentUser
        self.selectedEpisode = selectedEpisode
        self.categories = categories
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

            if categories.isEmpty {
                Text("No categories configured for this phase.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    section(for: category)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay {
            if isCurrentUser {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color(red: 0.07, green: 0.19, blue: 0.42),
                        lineWidth: 3
                    )
            }
        }
    }

    @ViewBuilder
    private func section(for category: PickPhase.Category) -> some View {
        let title = displayTitle(for: category)
        let kind = kind(for: category)
        let contestants = contestants(for: category, kind: kind)

        if isCurrentUser {
            switch kind {
            case .seasonMerge:
                NavigationLink {
                    MergePickEditor()
                } label: {
                    PickSection(title: title, contestants: contestants, isInteractive: true)
                }
            case .seasonFinalThree:
                NavigationLink {
                    FinalThreePickEditor()
                } label: {
                    PickSection(title: title, contestants: contestants, isInteractive: true)
                }
            case .seasonWinner:
                NavigationLink {
                    WinnerPickEditor()
                } label: {
                    PickSection(title: title, contestants: contestants, isInteractive: true)
                }
            case let .weekly(panel):
                if let episode = selectedEpisode {
                    NavigationLink {
                        WeeklyPickEditor(episode: episode, panel: panel)
                    } label: {
                        PickSection(title: title, contestants: contestants, isInteractive: true)
                    }
                } else {
                    PickSection(title: title, contestants: contestants)
                }
            case .unknown:
                PickSection(title: title, contestants: contestants)
            }
        } else {
            PickSection(title: title, contestants: contestants)
        }
    }

    private enum CategoryKind {
        case seasonMerge
        case seasonFinalThree
        case seasonWinner
        case weekly(WeeklyPickPanel)
        case unknown
    }

    private func displayTitle(for category: PickPhase.Category) -> String {
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Category" : trimmed
    }

    private func kind(for category: PickPhase.Category) -> CategoryKind {
        let normalized = category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("merge") {
            return .seasonMerge
        }

        if normalized.contains("final") && (normalized.contains("three") || normalized.contains("3")) {
            return .seasonFinalThree
        }

        if normalized.contains("sole") && normalized.contains("survivor") {
            return .seasonWinner
        }

        let winnerPhrases: [String] = ["winner", "winner pick", "season winner", "survivor winner"]
        if winnerPhrases.contains(normalized) || normalized.contains("winner pick") {
            return .seasonWinner
        }

        if normalized.contains("immunity") {
            return .weekly(.immunity)
        }

        if normalized.contains("voted") || normalized.contains("vote") {
            return .weekly(.votedOut)
        }

        if normalized.contains("remain") || normalized.contains("safe") {
            return .weekly(.remain)
        }

        return .unknown
    }

    private func contestants(
        for ids: Set<String>,
        limit: Int? = nil
    ) -> [Contestant] {
        let picks = ids.compactMap { contestantsById[$0] }
            .sorted { $0.name < $1.name }
        if let limit {
            return Array(picks.prefix(limit))
        }
        return picks
    }

    private func contestants(for category: PickPhase.Category, kind: CategoryKind) -> [Contestant] {
        let limit: Int? = category.totalPicks > 0 ? category.totalPicks : nil

        switch kind {
        case .seasonMerge:
            return contestants(for: seasonPicks?.mergePicks ?? Set<String>(), limit: limit)
        case .seasonFinalThree:
            return contestants(for: seasonPicks?.finalThreePicks ?? Set<String>(), limit: limit)
        case .seasonWinner:
            if let winner = seasonPicks?.winnerPick {
                return contestants(for: Set([winner]), limit: 1)
            }
            return []
        case let .weekly(panel):
            switch panel {
            case .remain:
                return contestants(for: weeklyPicks?.remain ?? Set<String>(), limit: limit)
            case .votedOut:
                return contestants(for: weeklyPicks?.votedOut ?? Set<String>(), limit: limit)
            case .immunity:
                return contestants(for: weeklyPicks?.immunity ?? Set<String>(), limit: limit)
            }
        case .unknown:
            return []
        }
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

private enum WeekSelection: Hashable {
    case none
    case week(Int)
}

private extension WeekSelection {
    var weekId: Int? {
        if case let .week(id) = self { return id }
        return nil
    }
}

private struct WeekOption: Identifiable {
    let selection: WeekSelection
    let title: String

    var id: WeekSelection { selection }
}

#Preview {
    AllPicksView()
        .environmentObject(AppState())
}
