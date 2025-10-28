import SwiftUI

enum WeeklyPickPanel: Hashable {
    case remain
    case votedOut
    case immunity
    case custom(UUID)

    var categoryId: UUID? {
        if case let .custom(id) = self {
            return id
        }
        return nil
    }
}

struct WeeklyPickEditor: View {
    @EnvironmentObject var app: AppState
    let episode: Episode
    let panel: WeeklyPickPanel
    @State private var picks: WeeklyPicks

    init(episode: Episode, panel: WeeklyPickPanel) {
        self.episode = episode
        self.panel = panel
        _picks = State(initialValue: WeeklyPicks(userId: "", episodeId: episode.id))
    }

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let phase = app.scoring.phase(for: episode)
        let caps = (phase == .preMerge) ? config.weeklyPickCapsPreMerge : config.weeklyPickCapsPostMerge
        let limit = phaseCategoryLimit(for: panel) ?? selectionLimit(for: panel, caps: caps)
        let locked = picksLocked(for: episode, userId: userId, store: app.store)
        let contestants = availableContestants()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if locked {
                    LockPill(text: "Locked for \(episode.title)")
                } else {
                    Text(instructionText(for: panel, limit: limit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LimitedMultiSelect(
                    all: contestants,
                    selection: Binding(
                        get: { selection(for: panel) },
                        set: { newValue in updateSelection(newValue, limit: limit, locked: locked) }
                    ),
                    max: limit,
                    disabled: locked
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle(for: panel))
        .onAppear { loadPicks(for: userId) }
        .onChange(of: episode.id) { _ in loadPicks(for: userId) }
        .onChange(of: app.currentUserId) { newValue in loadPicks(for: newValue) }
        .onChange(of: app.store.results) { _ in loadPicks(for: app.currentUserId) }
        .onChange(of: app.store.config.contestants) { _ in loadPicks(for: app.currentUserId) }
    }

    private func loadPicks(for userId: String) {
        var loaded = app.store.picks(for: userId, episodeId: episode.id)
        let allowedIds = availableContestantIDs()
        if pruneInvalidSelections(in: &loaded, allowedIds: allowedIds) {
            app.store.save(loaded)
        }
        picks = loaded
    }

    private func selection(for panel: WeeklyPickPanel) -> Set<String> {
        let allowedIds = availableContestantIDs()
        switch panel {
        case .remain:
            return picks.remain.intersection(allowedIds)
        case .votedOut:
            return picks.votedOut.intersection(allowedIds)
        case .immunity:
            return picks.immunity.intersection(allowedIds)
        case let .custom(categoryId):
            return picks.selections(for: categoryId).intersection(allowedIds)
        }
    }

    private func updateSelection(_ newValue: Set<String>, limit: Int, locked: Bool) {
        guard !locked else { return }
        let allowedIds = availableContestantIDs()
        let limited = Set(newValue.prefix(limit)).intersection(allowedIds)
        switch panel {
        case .remain:
            picks.remain = limited
        case .votedOut:
            picks.votedOut = limited
        case .immunity:
            picks.immunity = limited
        case let .custom(categoryId):
            picks.setSelections(limited, for: categoryId)
        }
        picks.isSubmitted = false
        app.store.save(picks)
    }

    private func selectionLimit(for panel: WeeklyPickPanel, caps: SeasonConfig.WeeklyPickCaps) -> Int {
        switch panel {
        case .remain:
            return caps.remain ?? 3
        case .votedOut:
            return caps.votedOut ?? 3
        case .immunity:
            return caps.immunity ?? 3
        case .custom:
            return defaultCustomLimit
        }
    }

    private func phaseCategoryLimit(for panel: WeeklyPickPanel) -> Int? {
        let matchingCategory: PickPhase.Category?

        switch panel {
        case .remain:
            matchingCategory = app.activePhase?.categories.first(where: { $0.matchesRemainCategory })
        case .votedOut:
            matchingCategory = app.activePhase?.categories.first(where: { $0.matchesVotedOutCategory })
        case .immunity:
            matchingCategory = app.activePhase?.categories.first(where: { $0.matchesImmunityCategory })
        case let .custom(categoryId):
            matchingCategory = category(withId: categoryId)
        }

        guard let total = matchingCategory?.totalPicks, total > 0 else { return nil }
        return total
    }

    private func navigationTitle(for panel: WeeklyPickPanel) -> String {
        switch panel {
        case .remain:
            return "Who Will Remain"
        case .votedOut:
            return "Who Will be Voted Out"
        case .immunity:
            return "Who Will Have Immunity"
        case let .custom(categoryId):
            return categoryName(for: categoryId)
        }
    }

    private func instructionText(for panel: WeeklyPickPanel, limit: Int) -> String {
        switch panel {
        case .remain:
            return "Select up to \(limit) players you expect to stay safe this week."
        case .votedOut:
            return "Select up to \(limit) players you think will be voted out."
        case .immunity:
            return "Select up to \(limit) players you think will win immunity."
        case let .custom(categoryId):
            let name = categoryName(for: categoryId)
            return "Select up to \(limit) players for \(name)."
        }
    }

    private var defaultCustomLimit: Int {
        guard let categoryId = panel.categoryId,
              let category = category(withId: categoryId)
        else { return 3 }

        return max(category.totalPicks, 1)
    }

    private func categoryName(for categoryId: UUID) -> String {
        guard let category = category(withId: categoryId) else {
            return "Category"
        }

        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Category" : trimmed
    }

    private func category(withId id: UUID) -> PickPhase.Category? {
        if let category = app.activePhase?.categories.first(where: { $0.id == id }) {
            return category
        }

        for phase in app.phases {
            if let category = phase.categories.first(where: { $0.id == id }) {
                return category
            }
        }

        return nil
    }

    private func availableContestants() -> [Contestant] {
        app.activeContestants(beforeEpisodeId: episode.id)
    }

    private func availableContestantIDs() -> Set<String> {
        app.activeContestantIDs(beforeEpisodeId: episode.id)
    }

    private func pruneInvalidSelections(in picks: inout WeeklyPicks, allowedIds: Set<String>) -> Bool {
        var didChange = false

        let remain = picks.remain.intersection(allowedIds)
        if remain != picks.remain {
            picks.remain = remain
            didChange = true
        }

        let votedOut = picks.votedOut.intersection(allowedIds)
        if votedOut != picks.votedOut {
            picks.votedOut = votedOut
            didChange = true
        }

        let immunity = picks.immunity.intersection(allowedIds)
        if immunity != picks.immunity {
            picks.immunity = immunity
            didChange = true
        }

        var updatedCategorySelections: [UUID: Set<String>] = [:]
        for (categoryId, selection) in picks.categorySelections {
            let filtered = selection.intersection(allowedIds)
            if !filtered.isEmpty {
                updatedCategorySelections[categoryId] = filtered
            }

            if filtered != selection {
                didChange = true
            }
        }

        if updatedCategorySelections != picks.categorySelections {
            picks.categorySelections = updatedCategorySelections
        }

        return didChange
    }
}
