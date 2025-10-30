import Foundation
import SwiftUI

struct AllPicksView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedWeek: WeekSelection = .none
    @State private var knownWeekIds: Set<Int> = []
    @State private var collapsedUserIds: Set<String> = []

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

    private var usersInDisplayOrder: [UserProfile] {
        guard let currentUserIndex = app.store.users.firstIndex(where: { $0.id == app.currentUserId }) else {
            return app.store.users
        }

        var orderedUsers = app.store.users
        let currentUser = orderedUsers.remove(at: currentUserIndex)
        orderedUsers.insert(currentUser, at: 0)
        return orderedUsers
    }

    private var hasConfiguredPickData: Bool {
        guard let activePhase else { return false }
        return !activePhase.categories.isEmpty
    }

    private var activePhase: PickPhase? {
        app.activePhase
    }

    private var activePhaseName: String {
        activePhase?.name ?? "Phase"
    }

    private var selectedEpisode: Episode? {
        guard case let .week(episodeId) = selectedWeek else { return nil }
        return episode(for: episodeId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if hasConfiguredPickData {
                        weekPicker
                            .padding(.bottom, 8)

                        ForEach(usersInDisplayOrder) { user in
                            let isCurrentUser = user.id == app.currentUserId
                            let isLocked = shouldLockPicks(for: user)
                            let isCollapsed = collapsedUserIds.contains(user.id)

                            UserPicksCard(
                                user: user,
                                weeklyPicks: isLocked ? nil : weeklyPicks(for: user),
                                contestantsById: contestantsById,
                                isCurrentUser: isCurrentUser,
                                isLocked: isLocked,
                                selectedEpisode: selectedEpisode,
                                categories: activePhaseCategories,
                                seasonConfig: app.store.config,
                                scoringEngine: app.scoring,
                                isCollapsed: isCurrentUser ? false : (isLocked ? false : isCollapsed),
                                onSubmitWeeklyPicks: isCurrentUser ? { submitWeeklyPicks(for: user) } : nil,
                                onToggleCollapse: (isCurrentUser || isLocked) ? nil : {
                                    withAnimation(.easeInOut) {
                                        if isCollapsed {
                                            collapsedUserIds.remove(user.id)
                                        } else {
                                            collapsedUserIds.insert(user.id)
                                        }
                                    }
                                }
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
            Text(activePhaseName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Picker(activePhaseName, selection: $selectedWeek) {
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

    func weeklyPicks(for user: UserProfile) -> WeeklyPicks? {
        guard case let .week(episodeId) = selectedWeek else { return nil }
        if var picks = app.store.weeklyPicks[user.id]?[episodeId] {
            if app.applyLockedSelections(for: user.id, picks: &picks) {
                app.store.save(picks)
            }
            return picks
        }

        guard user.id == app.currentUserId else { return nil }

        var picks = WeeklyPicks(userId: user.id, episodeId: episodeId)
        if app.applyLockedSelections(for: user.id, picks: &picks) {
            app.store.save(picks)
        }
        return picks
    }

    func shouldLockPicks(for user: UserProfile) -> Bool {
        let currentUserId = app.currentUserId

        guard user.id != currentUserId,
              !currentUserId.isEmpty,
              let weekId = selectedWeek.weekId else {
            return false
        }

        guard let picks = app.store.weeklyPicks[currentUserId]?[weekId] else {
            return true
        }

        return !picks.isSubmitted
    }

    func submitWeeklyPicks(for user: UserProfile) {
        guard let episode = selectedEpisode else { return }
        app.store.submitWeeklyPicks(for: user.id, episodeId: episode.id)
    }

    func episode(for episodeId: Int) -> Episode {
        if let configuredEpisode = app.store.config.episodes.first(where: { $0.id == episodeId }) {
            return configuredEpisode
        }

        let sortedEpisodes = app.store.config.episodes.sorted { $0.id < $1.id }
        let precedingEpisode = sortedEpisodes.last(where: { $0.id < episodeId })

        let baseDate = precedingEpisode?.airDate ?? Date()
        let inferredAirDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: baseDate) ?? baseDate

        let fallbackTitle = weekOptions.first(where: { $0.selection.weekId == episodeId })?.title
            ?? "Week \(episodeId)"

        return Episode(
            id: episodeId,
            airDate: inferredAirDate,
            title: fallbackTitle,
            isMergeEpisode: precedingEpisode?.isMergeEpisode ?? false
        )
    }

}

private struct UserPicksCard: View {
    @EnvironmentObject private var app: AppState
    let user: UserProfile
    let weeklyPicks: WeeklyPicks?
    let contestantsById: [String: Contestant]
    let isCurrentUser: Bool
    let isLocked: Bool
    let selectedEpisode: Episode?
    let categories: [PickPhase.Category]
    let seasonConfig: SeasonConfig
    let scoringEngine: ScoringEngine
    let isCollapsed: Bool
    let onSubmitWeeklyPicks: (() -> Void)?
    let onToggleCollapse: (() -> Void)?

    @State private var isHoldToSubmitActive = false
    @State private var holdToSubmitProgress: Double = 0

    init(
        user: UserProfile,
        weeklyPicks: WeeklyPicks?,
        contestantsById: [String: Contestant],
        isCurrentUser: Bool,
        isLocked: Bool,
        selectedEpisode: Episode?,
        categories: [PickPhase.Category],
        seasonConfig: SeasonConfig,
        scoringEngine: ScoringEngine,
        isCollapsed: Bool,
        onSubmitWeeklyPicks: (() -> Void)?,
        onToggleCollapse: (() -> Void)?
    ) {
        self.user = user
        self.weeklyPicks = weeklyPicks
        self.contestantsById = contestantsById
        self.isCurrentUser = isCurrentUser
        self.isLocked = isLocked
        self.selectedEpisode = selectedEpisode
        self.categories = categories
        self.seasonConfig = seasonConfig
        self.scoringEngine = scoringEngine
        self.isCollapsed = isCollapsed
        self.onSubmitWeeklyPicks = onSubmitWeeklyPicks
        self.onToggleCollapse = onToggleCollapse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isLocked {
                lockedNotice
            } else if isCollapsed {
                Text("Picks hidden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if categories.isEmpty {
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
        .overlay(alignment: .top) {
            if isCurrentUser, isHoldToSubmitActive {
                HoldProgressBar(progress: holdToSubmitProgress)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func section(for category: PickPhase.Category) -> some View {
        let title = displayTitle(for: category)
        let kind = kind(for: category)
        let contestants = contestants(for: category, kind: kind)
        let correctContestantIDs = correctContestantIDs(for: category, kind: kind)

        if isCurrentUser {
            switch kind {
            case let .weekly(panel):
                let canEditWeeklyPicks = !(weeklyPicks?.isSubmitted ?? false)
                let canNavigate = canEditWeeklyPicks && canEditCategory(category)

                if let episode = selectedEpisode, canNavigate {
                    NavigationLink {
                        WeeklyPickEditor(episode: episode, panel: panel)
                    } label: {
                        PickSection(
                            title: title,
                            contestants: contestants,
                            isInteractive: true,
                            correctContestantIDs: correctContestantIDs
                        )
                    }
                } else {
                    PickSection(
                        title: title,
                        contestants: contestants,
                        isInteractive: canNavigate,
                        correctContestantIDs: correctContestantIDs
                    )
                }
            case .unknown:
                PickSection(
                    title: title,
                    contestants: contestants,
                    correctContestantIDs: correctContestantIDs
                )
            }
        } else {
            PickSection(
                title: title,
                contestants: contestants,
                correctContestantIDs: correctContestantIDs
            )
        }
    }

    private enum CategoryKind {
        case weekly(WeeklyPickPanel)
        case unknown
    }

    private func canEditCategory(_ category: PickPhase.Category) -> Bool {
        guard category.isLocked else { return true }
        guard let episode = selectedEpisode else { return false }
        guard let phaseInfo = app.phaseContext(forEpisodeId: episode.id) else { return true }

        return !hasSelections(for: category, phaseId: phaseInfo.phaseId)
    }

    private func hasSelections(for category: PickPhase.Category, phaseId: PickPhase.ID) -> Bool {
        guard let picksByEpisode = app.store.weeklyPicks[user.id] else { return false }

        let episodeIds = app.phaseEpisodeIds(for: phaseId)

        for episodeId in episodeIds {
            guard let picks = picksByEpisode[episodeId] else { continue }
            let selection = app.selections(for: category, in: picks)
            if !selection.isEmpty {
                return true
            }
        }

        return false
    }

    private func displayTitle(for category: PickPhase.Category) -> String {
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Category" : trimmed
    }

    private func kind(for category: PickPhase.Category) -> CategoryKind {
        switch category.kind {
        case .remain:
            return .weekly(.remain)
        case .votedOut:
            return .weekly(.votedOut)
        case .immunity:
            return .weekly(.immunity)
        case .custom:
            return .weekly(.custom(category.id))
        }
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
        let limit: Int? = selectionLimit(for: category, kind: kind)

        switch kind {
        case let .weekly(panel):
            switch panel {
            case .remain:
                return contestants(for: weeklyPicks?.remain ?? Set<String>(), limit: limit)
            case .votedOut:
                return contestants(for: weeklyPicks?.votedOut ?? Set<String>(), limit: limit)
            case .immunity:
                return contestants(for: weeklyPicks?.immunity ?? Set<String>(), limit: limit)
            case let .custom(categoryId):
                return contestants(for: weeklyPicks?.selections(for: categoryId) ?? Set<String>(), limit: limit)
            }
        case .unknown:
            return []
        }
    }

    private func correctContestantIDs(for category: PickPhase.Category, kind: CategoryKind) -> Set<String> {
        switch kind {
        case .unknown:
            return []

        case let .weekly(panel):
            guard let episode = selectedEpisode,
                  let result = scoringEngine.resultsByEpisode[episode.id],
                  result.hasRecordedResults
            else {
                return []
            }

            switch panel {
            case .remain:
                guard let weeklyPicks = self.weeklyPicks else { return [] }
                if category.autoScoresRemainingContestants {
                    guard !result.votedOut.isEmpty else { return [] }
                    let votedOutIds = Set(result.votedOut)
                    return weeklyPicks.remain.subtracting(votedOutIds)
                } else {
                    let winners = Set(result.winners(for: category.id))
                    guard !winners.isEmpty else { return [] }
                    return weeklyPicks.remain.intersection(winners)
                }
            case .votedOut:
                let votedOutIds = Set(result.votedOut)
                guard let weeklyPicks = self.weeklyPicks else { return [] }
                return weeklyPicks.votedOut.intersection(votedOutIds)
            case .immunity:
                guard let weeklyPicks = self.weeklyPicks else { return [] }
                return weeklyPicks.immunity.intersection(Set(result.immunityWinners))
            case let .custom(categoryId):
                guard let weeklyPicks = self.weeklyPicks else { return [] }
                let winners = Set(result.winners(for: categoryId))
                guard !winners.isEmpty else { return [] }
                let selections = weeklyPicks.selections(for: categoryId)
                return selections.intersection(winners)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if isCurrentUser {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    NavigationLink {
                        ActiveUserProfileView(user: user)
                    } label: {
                        avatarView(for: user, size: 44)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View profile")
                    .accessibilityHint("Open your profile to sign out")

                    Spacer()

                    if let onSubmitWeeklyPicks {
                        SubmitPicksButton(
                            isSubmitted: weeklyPicks?.isSubmitted ?? false,
                            isEnabled: selectedEpisode != nil,
                            onSubmit: onSubmitWeeklyPicks,
                            isHolding: $isHoldToSubmitActive,
                            progress: $holdToSubmitProgress
                        )
                    }
                }

                NavigationLink {
                    ActiveUserProfileView(user: user)
                } label: {
                    Text(user.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View profile")
                .accessibilityHint("Open your profile to sign out")
            }
        } else {
            HStack(spacing: 12) {
                avatarView(for: user, size: 44)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Picks locked")
                } else if let onToggleCollapse {
                    Button {
                        onToggleCollapse()
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .imageScale(.medium)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCollapsed ? "Show picks" : "Hide picks")
                    .accessibilityHint("Toggle to show or hide picks for \(user.displayName)")
                }
            }
        }
    }

    @ViewBuilder
    private func avatarView(for user: UserProfile, size: CGFloat) -> some View {
        if let url = user.avatarURL {
            StorageAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                picksAvatarPlaceholder(size: size)
            }
        } else {
            picksAvatarPlaceholder(size: size)
        }
    }

    @ViewBuilder
    private func picksAvatarPlaceholder(size: CGFloat) -> some View {
        Image(systemName: "person.fill")
            .resizable()
            .scaledToFit()
            .padding(size * 0.3)
            .foregroundStyle(.secondary)
    }
}

private extension UserPicksCard {
    private var lockedNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "eye.slash")
                .imageScale(.medium)
                .foregroundStyle(.secondary)

            Text(lockedMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var lockedMessage: String {
        if let episode = selectedEpisode {
            return "Submit your picks for \(episode.title) to view others."
        }

        return "Submit your picks for this week to view others."
    }

    private func selectionLimit(for category: PickPhase.Category, kind: CategoryKind) -> Int? {
        switch kind {
        case .weekly(let panel):
            if case .custom = panel {
                return positiveLimit(from: category.totalPicks)
            }

            guard let episode = selectedEpisode else {
                return positiveLimit(from: category.totalPicks)
            }

            let phase = scoringEngine.phase(for: episode)
            let caps = (phase == .preMerge) ? seasonConfig.weeklyPickCapsPreMerge : seasonConfig.weeklyPickCapsPostMerge

            return limit(for: panel, caps: caps)

        case .unknown:
            return positiveLimit(from: category.totalPicks)
        }
    }

    private func limit(for panel: WeeklyPickPanel, caps: SeasonConfig.WeeklyPickCaps) -> Int? {
        switch panel {
        case .remain:
            return caps.remain ?? 3
        case .votedOut:
            return caps.votedOut ?? 3
        case .immunity:
            return caps.immunity ?? 3
        case .custom:
            return nil
        }
    }

    private func positiveLimit(from value: Int) -> Int? {
        value > 0 ? value : nil
    }
}

private struct SubmitPicksButton: View {
    let isSubmitted: Bool
    let isEnabled: Bool
    let onSubmit: () -> Void

    @Binding var isHolding: Bool
    @Binding var progress: Double

    @GestureState private var isPressing = false
    @State private var holdTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 3
    private let completionDisplayDuration: TimeInterval = 0.3

    var body: some View {
        Button(action: {}) {
            Text(buttonTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSubmitted ? Color.green : Color.accentColor)
        .simultaneousGesture(longPressGesture)
        .scaleEffect(isPressing ? 0.96 : 1)
        .disabled(!isEnabled || isSubmitted)
        .accessibilityLabel(isSubmitted ? "Picks submitted" : "Submit picks")
        .accessibilityHint(accessibilityHint)
        .onChange(of: isPressing) { newValue in
            if newValue {
                beginHoldAnimation()
            } else if isHolding && progress < 0.999 {
                cancelHoldAnimation()
            }
        }
        .onChange(of: isSubmitted) { newValue in
            if newValue {
                cancelHoldAnimation()
            }
        }
    }

    private var buttonTitle: String {
        isSubmitted ? "Submitted" : "Submit Picks"
    }

    private var accessibilityHint: String {
        if isSubmitted {
            return "Your picks for this week have already been submitted."
        } else if isEnabled {
            return "Press and hold for three seconds to submit this week's picks."
        } else {
            return "Select a week to enable submissions."
        }
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: holdDuration)
            .updating($isPressing) { currentState, state, _ in
                state = currentState
            }
            .onEnded { success in
                let canSubmit = success && isEnabled && !isSubmitted

                if canSubmit {
                    completeHoldAnimation()
                    onSubmit()
                } else {
                    cancelHoldAnimation()
                }
            }
    }

    private func beginHoldAnimation() {
        guard !isHolding, isEnabled, !isSubmitted else { return }

        isHolding = true
        progress = 0
        startHoldProgressTask()
    }

    private func cancelHoldAnimation() {
        guard isHolding else { return }

        stopHoldProgressTask()
        isHolding = false

        withAnimation(.easeOut(duration: 0.15)) {
            progress = 0
        }
    }

    private func completeHoldAnimation() {
        guard isHolding else { return }

        stopHoldProgressTask()
        progress = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + completionDisplayDuration) {
            isHolding = false

            withAnimation(.easeInOut(duration: 0.2)) {
                progress = 0
            }
        }
    }

    private func startHoldProgressTask() {
        stopHoldProgressTask()

        holdTask = Task {
            let startDate = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startDate)
                let newProgress = min(elapsed / holdDuration, 1)

                await MainActor.run {
                    progress = newProgress
                }

                if newProgress >= 1 {
                    break
                }

                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    private func stopHoldProgressTask() {
        holdTask?.cancel()
        holdTask = nil
    }
}

private struct HoldProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let clampedProgress = max(0, min(progress, 1))
            let totalWidth = geometry.size.width * 0.9
            let width = totalWidth * CGFloat(clampedProgress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: totalWidth, alignment: .leading)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: width, alignment: .leading)
            }
            .frame(width: totalWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 4)
    }
}

private struct PickSection: View {
    let title: String
    let contestants: [Contestant]
    let isInteractive: Bool
    let correctContestantIDs: Set<String>

    init(
        title: String,
        contestants: [Contestant],
        isInteractive: Bool = false,
        correctContestantIDs: Set<String> = []
    ) {
        self.title = title
        self.contestants = contestants
        self.isInteractive = isInteractive
        self.correctContestantIDs = correctContestantIDs
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
                            ZStack(alignment: .topTrailing) {
                                ContestantAvatar(contestant: contestant, size: 60)

                                if correctContestantIDs.contains(contestant.id) {
                                    checkmarkBadge
                                        .offset(x: 4, y: -4)
                                }
                            }

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

    private var checkmarkBadge: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            Circle()
                .fill(Color(.systemGreen))
                .frame(width: 24, height: 24)

            Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white)
        }
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
        .environmentObject(AppState.preview)
}
