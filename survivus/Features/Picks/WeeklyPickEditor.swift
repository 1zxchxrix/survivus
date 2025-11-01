import SwiftUI

struct WeeklyPickEditor: View {
    @EnvironmentObject var app: AppState
    let episode: Episode
    let categoryId: PickPhase.Category.ID
    @State private var picks: WeeklyPicks
    @State private var wagerInput: String = ""

    init(episode: Episode, categoryId: PickPhase.Category.ID) {
        self.episode = episode
        self.categoryId = categoryId
        _picks = State(initialValue: WeeklyPicks(userId: "", episodeId: episode.id))
    }

    var body: some View {
        let config = app.store.config
        let userId = app.currentUserId
        let category = resolvedCategory
        let limit = max(selectionLimit(for: category), 1)
        let locked = picksLocked(for: episode, userId: userId, store: app.store)
        let categoryLocked = category.map { isCategoryLockedForEditing($0, userId: userId) } ?? true

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if locked {
                    LockPill(text: "Locked for \(episode.title)")
                } else if categoryLocked {
                    LockPill(text: "Locked for this phase")
                } else if let category {
                    Text(instructionText(for: category, limit: limit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let category, category.usesWager {
                    wagerField(for: category, locked: locked || categoryLocked, userId: userId)
                }

                LimitedMultiSelect(
                    all: config.contestants,
                    selection: Binding(
                        get: { selection(for: categoryId) },
                        set: { newValue in updateSelection(newValue, limit: limit, locked: locked, userId: userId) }
                    ),
                    max: limit,
                    disabled: locked || categoryLocked || category == nil
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(categoryDisplayName(for: category))
        .onAppear { loadPicks(for: userId) }
        .onChange(of: episode.id) { _ in loadPicks(for: userId) }
        .onChange(of: app.currentUserId) { newValue in loadPicks(for: newValue) }
    }

    private var resolvedCategory: PickPhase.Category? {
        if let category = phaseContext?.phase.categories.first(where: { $0.id == categoryId }) {
            return category
        }

        if let category = app.activePhase?.categories.first(where: { $0.id == categoryId }) {
            return category
        }

        for phase in app.phases {
            if let category = phase.categories.first(where: { $0.id == categoryId }) {
                return category
            }
        }

        return nil
    }

    private func loadPicks(for userId: String) {
        var weeklyPicks = app.store.picks(for: userId, episodeId: episode.id)
        let didApplyLockedSelections = app.applyLockedSelections(for: userId, picks: &weeklyPicks)
        picks = weeklyPicks
        wagerInput = weeklyPicks.wager(for: categoryId).map(String.init) ?? ""

        if didApplyLockedSelections {
            app.store.save(weeklyPicks)
        }
    }

    private func selection(for categoryId: UUID) -> Set<String> {
        picks.selections(for: categoryId)
    }

    @ViewBuilder
    private func wagerField(for category: PickPhase.Category, locked: Bool, userId: String) -> some View {
        TextField("±Wager", text: Binding(
            get: { wagerInput },
            set: { newValue in updateWager(newValue, for: category, locked: locked, userId: userId) }
        ))
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
        .disabled(locked)
    }

    private func updateSelection(_ newValue: Set<String>, limit: Int, locked: Bool, userId: String) {
        guard !locked else { return }
        let editingUserId = picks.userId.isEmpty ? userId : picks.userId
        guard let category = resolvedCategory else { return }
        guard !isCategoryLockedForEditing(category, userId: editingUserId) else { return }

        let limited = Set(newValue.prefix(limit))
        picks.setSelections(limited, for: category.id)
        picks.isSubmitted = false
        app.store.save(picks)
    }

    private func updateWager(_ newValue: String, for category: PickPhase.Category, locked: Bool, userId: String) {
        let filtered = newValue.filter(\.isNumber)
        wagerInput = filtered

        guard !locked else { return }
        let editingUserId = picks.userId.isEmpty ? userId : picks.userId
        guard !isCategoryLockedForEditing(category, userId: editingUserId) else { return }

        let amount = filtered.isEmpty ? nil : Int(filtered)
        picks.setWager(amount, for: category.id)
        picks.isSubmitted = false
        app.store.save(picks)
    }

    private func selectionLimit(for category: PickPhase.Category?) -> Int {
        guard let category else { return 3 }
        let configured = category.totalPicks
        if configured > 0 {
            return configured
        }
        return 3
    }

    private func instructionText(for category: PickPhase.Category, limit: Int) -> String {
        let name = categoryDisplayName(for: category)
        return "Select up to \(limit) players for \(name)."
    }

    private func categoryDisplayName(for category: PickPhase.Category?) -> String {
        guard let category else { return "Category" }
        let trimmed = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        let columnId = category.columnId.trimmingCharacters(in: .whitespacesAndNewlines)
        return columnId.isEmpty ? "Category" : columnId
    }

    private func isCategoryLockedForEditing(_ category: PickPhase.Category, userId: String) -> Bool {
        guard category.isLocked else { return false }
        guard let phaseInfo = phaseContext else { return false }
        guard let originEpisodeId = originEpisodeId(for: category, phaseId: phaseInfo.phaseId, userId: userId) else {
            return false
        }
        return originEpisodeId != episode.id
    }

    private func originEpisodeId(for category: PickPhase.Category, phaseId: PickPhase.ID, userId: String) -> Int? {
        guard let picksByEpisode = app.store.weeklyPicks[userId] else { return nil }
        let episodeIds = app.phaseEpisodeIds(for: phaseId)

        for episodeId in episodeIds {
            guard let picks = picksByEpisode[episodeId] else { continue }
            let selection = app.selections(for: category, in: picks)
            if !selection.isEmpty {
                return episodeId
            }
        }

        return nil
    }

    private var phaseContext: (phase: PickPhase, phaseId: PickPhase.ID)? {
        app.phaseContext(forEpisodeId: episode.id)
    }
}
