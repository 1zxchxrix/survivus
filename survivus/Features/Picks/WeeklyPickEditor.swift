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
                    all: config.contestants,
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
    }

    private func loadPicks(for userId: String) {
        picks = app.store.picks(for: userId, episodeId: episode.id)
    }

    private func selection(for panel: WeeklyPickPanel) -> Set<String> {
        switch panel {
        case .remain:
            return picks.remain
        case .votedOut:
            return picks.votedOut
        case .immunity:
            return picks.immunity
        case let .custom(categoryId):
            return picks.selections(for: categoryId)
        }
    }

    private func updateSelection(_ newValue: Set<String>, limit: Int, locked: Bool) {
        guard !locked else { return }
        let limited = Set(newValue.prefix(limit))
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
}
