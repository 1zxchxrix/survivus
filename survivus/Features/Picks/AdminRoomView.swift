import SwiftUI

struct AdminRoomView: View {
    @EnvironmentObject var app: AppState
    @State private var isPresentingCreatePhase = false
    @State private var isPresentingSelectPhase = false
    @State private var isPresentingStartWeek = false
    @State private var phaseBeingEdited: PickPhase?
    @State private var phaseForInsertingResults: PickPhase?
    @State private var selectedPhaseForNewWeekID: PickPhase.ID?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Phase: \(currentPhase?.name ?? "None")")
                    Text("Current Week: \(currentWeekTitle)")
                }
            }

            Section("Week") {
                Button("Insert Results") {
                    if let phase = currentPhase, !phase.categories.isEmpty, currentWeekId != nil {
                        phaseForInsertingResults = phase
                    }
                }
                .disabled(!canInsertResults || !hasPhases)
                Button("Modify Previous Results") {}
                .disabled(!hasPhases)
                Button("Start New Week") {
                    selectedPhaseForNewWeekID = currentPhase?.id ?? phases.first?.id
                    isPresentingStartWeek = true
                }
                .disabled(!canStartNewWeek)
            }

            Section("Phase") {
                Button("Modify Phase") {
                    isPresentingSelectPhase = true
                }
                .disabled(!hasPhases)
                Button("Create New Phase") {
                    phaseBeingEdited = nil
                    isPresentingCreatePhase = true
                }
            }
        }
        .navigationTitle("Admin Room")
        .sheet(isPresented: $isPresentingStartWeek) {
            StartWeekSheet(
                phases: phases,
                selectedPhaseID: selectedPhaseForNewWeekID ?? currentPhase?.id,
                onStart: { phase in
                    selectedPhaseForNewWeekID = phase.id
                    startNewWeek(activating: phase)
                }
            )
        }
        .sheet(isPresented: $isPresentingSelectPhase) {
            SelectPhaseSheet(
                phases: phases,
                currentPhaseID: currentPhase?.id,
                onActivate: { phase in
                    app.activePhaseId = phase.id
                    isPresentingSelectPhase = false
                },
                onModify: { phase in
                    phaseBeingEdited = phase
                    isPresentingSelectPhase = false
                    isPresentingCreatePhase = true
                },
                onDelete: { phase in
                    app.phases.removeAll { $0.id == phase.id }
                    if app.activePhaseId == phase.id {
                        app.activePhaseId = app.phases.first?.id
                    }
                }
            )
        }
        .sheet(isPresented: $isPresentingCreatePhase, onDismiss: {
            phaseBeingEdited = nil
        }) {
            CreatePhaseSheet(phase: phaseBeingEdited) { phase in
                if let index = app.phases.firstIndex(where: { $0.id == phase.id }) {
                    app.phases[index] = phase
                } else {
                    app.phases.append(phase)
                }

                if app.activePhaseId == phase.id {
                    app.activePhaseId = phase.id
                } else if app.activePhaseId == nil {
                    app.activePhaseId = phase.id
                }
            }
            .presentationDetents([.fraction(0.8)])
            .presentationCornerRadius(28)
        }
        .sheet(item: $phaseForInsertingResults) { phase in
            if let episodeId = currentWeekId {
                InsertResultsSheet(
                    phase: phase,
                    contestants: app.store.config.contestants,
                    episodeId: episodeId,
                    existingResult: currentWeekResult,
                    onSave: { result in
                        if let index = app.store.results.firstIndex(where: { $0.id == result.id }) {
                            app.store.results[index] = result
                        } else {
                            app.store.results.append(result)
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
            .environmentObject(AppState())
    }
}

private extension AdminRoomView {
    var phases: [PickPhase] { app.phases }

    var currentPhase: PickPhase? {
        app.activePhase
    }

    var currentWeekTitle: String {
        guard let weekId = app.store.results.map(\.id).max() else {
            return "None"
        }

        if let episode = app.store.config.episodes.first(where: { $0.id == weekId }) {
            return episode.title
        }

        return "Week \(weekId)"
    }

    var canInsertResults: Bool {
        guard let phase = currentPhase, currentWeekId != nil else { return false }
        return !phase.categories.isEmpty
    }

    var hasPhases: Bool {
        !phases.isEmpty
    }

    var canStartNewWeek: Bool {
        hasPhases && hasSubmittedResultsForCurrentWeek
    }

    var hasSubmittedResultsForCurrentWeek: Bool {
        guard let latestResult = app.store.results.max(by: { $0.id < $1.id }) else {
            return true
        }

        return !latestResult.immunityWinners.isEmpty || !latestResult.votedOut.isEmpty
    }

    var currentWeekId: Int? {
        app.store.results.map(\.id).max()
    }

    var currentWeekResult: EpisodeResult? {
        guard let currentWeekId else { return nil }
        return app.store.results.first(where: { $0.id == currentWeekId })
    }

    func startNewWeek(activating phase: PickPhase) {
        let nextWeekId = (app.store.results.map(\.id).max() ?? 0) + 1
        let newResult = EpisodeResult(id: nextWeekId, immunityWinners: [], votedOut: [])
        app.store.results.append(newResult)
        app.activePhaseId = phase.id
    }
}

private struct StartWeekSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [PickPhase]
    let onStart: (PickPhase) -> Void

    @State private var selectedPhaseID: PickPhase.ID?

    init(phases: [PickPhase], selectedPhaseID: PickPhase.ID?, onStart: @escaping (PickPhase) -> Void) {
        self.phases = phases
        self.onStart = onStart
        _selectedPhaseID = State(initialValue: selectedPhaseID ?? phases.first?.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if phases.isEmpty {
                    ContentUnavailableView(
                        "No phases",
                        systemImage: "tray",
                        description: Text("Create a phase before starting a new week.")
                    )
                } else {
                    Form {
                        Section("Phase") {
                            Picker("Phase", selection: $selectedPhaseID) {
                                ForEach(phases) { phase in
                                    Text(phase.name).tag(Optional(phase.id))
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                }
            }
            .navigationTitle("Start New Week")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        if let id = selectedPhaseID,
                           let phase = phases.first(where: { $0.id == id }) {
                            onStart(phase)
                        }
                        dismiss()
                    }
                    .disabled(selectedPhaseID == nil)
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
        .presentationCornerRadius(28)
        .onAppear {
            if selectedPhaseID == nil {
                selectedPhaseID = phases.first?.id
            }
        }
    }
}

private struct CreatePhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phaseName: String
    @State private var categories: [CategoryDraft]
    @State private var isPresentingCategoryEditor = false
    @State private var categoryBeingEdited: CategoryDraft?

    private let phase: PickPhase?
    var onSave: (PickPhase) -> Void

    init(phase: PickPhase? = nil, onSave: @escaping (PickPhase) -> Void) {
        self.phase = phase
        self.onSave = onSave
        _phaseName = State(initialValue: phase?.name ?? "")
        _categories = State(initialValue: phase?.categories.map(CategoryDraft.init) ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Phase name", text: $phaseName)
                }

                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            Button {
                                categoryBeingEdited = category
                                isPresentingCategoryEditor = true
                            } label: {
                                CategoryRow(category: category)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    categories.removeAll { $0.id == category.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        categoryBeingEdited = nil
                        isPresentingCategoryEditor = true
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(phase == nil ? "Create Phase" : "Modify Phase")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingCategoryEditor, onDismiss: {
                categoryBeingEdited = nil
            }) {
                CategoryEditorSheet(category: categoryBeingEdited) { category in
                    if let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[index] = category
                    } else {
                        categories.append(category)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let phaseNameToSave = trimmedName.isEmpty ? "Untitled Phase" : trimmedName
                    let newPhase = PickPhase(
                        id: phase?.id ?? UUID(),
                        name: phaseNameToSave,
                        categories: categories.map { PickPhase.Category($0) }
                    )
                    onSave(newPhase)
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

private struct CategoryRow: View {
    let category: CategoryDraft

    private var displayName: String {
        let trimmedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Untitled Category" : trimmedName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Total picks: \(category.totalPicks)")

                if let points = category.pointsPerCorrectPick {
                    Text("Points per correct pick: \(points)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if category.isLocked {
                Text("Locked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CategoryDraft
    @State private var pointsInput: String

    var onSave: (CategoryDraft) -> Void

    init(category: CategoryDraft?, onSave: @escaping (CategoryDraft) -> Void) {
        var initialDraft = category ?? CategoryDraft()
        initialDraft.totalPicks = max(1, min(initialDraft.totalPicks, 5))

        _draft = State(initialValue: initialDraft)
        _pointsInput = State(initialValue: initialDraft.pointsPerCorrectPick.map(String.init) ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category name", text: $draft.name)

                    Picker("Total picks", selection: $draft.totalPicks) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)

                    TextField("Points per correct pick", text: Binding(
                        get: { pointsInput },
                        set: { newValue in
                            let filtered = newValue.filter(\.isNumber)
                            pointsInput = filtered
                            draft.pointsPerCorrectPick = filtered.isEmpty ? nil : Int(filtered)
                        }
                    ))
                    .keyboardType(.numberPad)

                    Toggle("Lock category", isOn: $draft.isLocked)
                }

                Section {
                    Button("Save") {
                        saveCategory()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveCategory() {
        var categoryToSave = draft

        if let value = Int(pointsInput), !pointsInput.isEmpty {
            categoryToSave.pointsPerCorrectPick = value
        } else {
            categoryToSave.pointsPerCorrectPick = nil
        }

        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            categoryToSave.name = "Untitled Category"
        } else {
            categoryToSave.name = trimmedName
        }

        onSave(categoryToSave)
        dismiss()
    }
}

private struct SelectPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [PickPhase]
    let currentPhaseID: PickPhase.ID?
    let onActivate: (PickPhase) -> Void
    let onModify: (PickPhase) -> Void
    let onDelete: (PickPhase) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if phases.isEmpty {
                    ContentUnavailableView(
                        "No phases",
                        systemImage: "tray",
                        description: Text("Create a new phase to activate it here.")
                    )
                } else {
                    List {
                        ForEach(phases) { phase in
                            PhaseRow(
                                phase: phase,
                                isActive: phase.id == currentPhaseID,
                                onActivate: {
                                    onActivate($0)
                                    dismiss()
                                },
                                onModify: onModify,
                                onDelete: onDelete
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Modify Phase")
        }
        .presentationDetents([.fraction(0.8)])
        .presentationCornerRadius(28)
    }
}

private struct InsertResultsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phase: PickPhase
    let contestants: [Contestant]
    let episodeId: Int
    let existingResult: EpisodeResult?
    let onSave: (EpisodeResult) -> Void

    @State private var selections: [PickPhase.Category.ID: Set<String>]

    init(
        phase: PickPhase,
        contestants: [Contestant],
        episodeId: Int,
        existingResult: EpisodeResult?,
        onSave: @escaping (EpisodeResult) -> Void
    ) {
        self.phase = phase
        self.contestants = contestants
        self.episodeId = episodeId
        self.existingResult = existingResult
        self.onSave = onSave

        let insertableCategories = phase.categories.filter { !$0.isLocked }

        var initialSelections = Dictionary(
            uniqueKeysWithValues: insertableCategories.map { ($0.id, Set<String>()) }
        )

        if let existingResult {
            if let immunityCategory = insertableCategories.first(where: { $0.matchesImmunityCategory }) {
                initialSelections[immunityCategory.id] = Set(existingResult.immunityWinners)
            }

            if let votedOutCategory = insertableCategories.first(where: { $0.matchesVotedOutCategory }) {
                initialSelections[votedOutCategory.id] = Set(existingResult.votedOut)
            }
        }

        _selections = State(initialValue: initialSelections)
    }

    var body: some View {
        NavigationStack {
            Group {
                if insertableCategories.isEmpty {
                    ContentUnavailableView(
                        "No categories",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add categories to this phase to insert results.")
                    )
                } else if contestants.isEmpty {
                    ContentUnavailableView(
                        "No contestants",
                        systemImage: "person.2",
                        description: Text("Contestants must be configured before inserting results.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(phase.name)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(insertableCategories) { category in
                                categoryCard(for: category)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Insert Results")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = buildEpisodeResult()
                        onSave(result)
                        dismiss()
                    }
                    .disabled(insertableCategories.isEmpty || contestants.isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationCornerRadius(28)
    }

    private var insertableCategories: [PickPhase.Category] {
        phase.categories.filter { !$0.isLocked }
    }

    @ViewBuilder
    private func categoryCard(for category: PickPhase.Category) -> some View {
        let displayName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = displayName.isEmpty ? "Untitled Category" : displayName
        let limit = max(category.totalPicks, 1)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                if category.isLocked {
                    LockPill(text: "Locked")
                }
            }

            Text("Select up to \(limit) contestant\(limit == 1 ? "" : "s").")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LimitedMultiSelect(
                all: contestants,
                selection: binding(for: category),
                max: limit,
                disabled: category.isLocked
            )

            if let points = category.pointsPerCorrectPick {
                Text("Worth \(points) point\(points == 1 ? "" : "s") per correct pick.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func binding(for category: PickPhase.Category) -> Binding<Set<String>> {
        Binding(
            get: { selections[category.id] ?? Set<String>() },
            set: { selections[category.id] = $0 }
        )
    }

    private func buildEpisodeResult() -> EpisodeResult {
        var result = existingResult ?? EpisodeResult(id: episodeId, immunityWinners: [], votedOut: [])

        if let immunityCategory = insertableCategories.first(where: { $0.matchesImmunityCategory }) {
            result.immunityWinners = sortedSelection(for: immunityCategory)
        }

        if let votedOutCategory = insertableCategories.first(where: { $0.matchesVotedOutCategory }) {
            result.votedOut = sortedSelection(for: votedOutCategory)
        }

        return result
    }

    private func sortedSelection(for category: PickPhase.Category) -> [String] {
        Array(selections[category.id] ?? []).sorted()
    }
}

#Preview("Insert Results Sheet") {
    InsertResultsSheet(
        phase: .preview,
        contestants: AppState().store.config.contestants,
        episodeId: 1,
        existingResult: EpisodeResult(id: 1, immunityWinners: [], votedOut: []),
        onSave: { _ in }
    )
}

private struct PhaseRow: View {
    let phase: PickPhase
    let isActive: Bool
    let onActivate: (PickPhase) -> Void
    let onModify: (PickPhase) -> Void
    let onDelete: (PickPhase) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phase.name)
                    .font(.headline)

                if isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if !phase.categories.isEmpty {
                Text("Categories: \(phase.categories.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onModify(phase)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(phase)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onActivate(phase)
            } label: {
                Label("Activate", systemImage: "checkmark.circle")
            }
            .tint(.blue)
        }
    }
}
