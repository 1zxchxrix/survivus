import SwiftUI

struct AdminRoomView: View {
    @EnvironmentObject var app: AppState
    @State private var isPresentingNewPhase = false
    @State private var isPresentingSelectPhase = false
    @State private var isPresentingStartWeek = false
    @State private var isPresentingManageContestants = false
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
                    isPresentingNewPhase = true
                }
            }

            Section("Season") {
                Button("Manage Contestants") {
                    isPresentingManageContestants = true
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
                lockedPhaseIDs: app.activatedPhaseIDs,
                onActivate: { phase in
                    app.activePhaseId = phase.id
                    isPresentingSelectPhase = false
                },
                onModify: { phase in
                    guard !app.hasPhaseEverBeenActive(phase.id) else { return }
                    phaseBeingEdited = phase
                    isPresentingSelectPhase = false
                },
                onDelete: { phase in
                    app.phases.removeAll { $0.id == phase.id }
                    if app.activePhaseId == phase.id {
                        app.activePhaseId = nil
                    }
                }
            )
        }
        .sheet(isPresented: $isPresentingNewPhase) {
            CreatePhaseSheet(phase: nil) { newPhase in
                handlePhaseSave(newPhase)
                isPresentingNewPhase = false
            }
            .presentationDetents([.fraction(0.8)])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isPresentingManageContestants) {
            ManageContestantsSheet(contestants: app.store.config.contestants) { contestants in
                app.store.config.contestants = contestants
            }
        }
        .sheet(item: $phaseBeingEdited) { phase in
            CreatePhaseSheet(phase: phase) { updatedPhase in
                handlePhaseSave(updatedPhase)
                phaseBeingEdited = nil
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
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
            .environmentObject(AppState.preview)
    }
}

private struct ManageContestantsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var contestants: [ContestantDraft]
    @State private var editMode: EditMode = .inactive

    let onSave: ([Contestant]) -> Void

    init(contestants: [Contestant], onSave: @escaping ([Contestant]) -> Void) {
        _contestants = State(initialValue: contestants.map(ContestantDraft.init))
        self.onSave = onSave
    }

    private var duplicateIds: Set<String> {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for id in contestants.map({ $0.normalizedIdentifier }).filter({ !$0.isEmpty }) {
            if !seen.insert(id).inserted {
                duplicates.insert(id)
            }
        }

        return duplicates
    }

    private var hasValidContestants: Bool {
        guard !contestants.contains(where: { $0.trimmedName.isEmpty || $0.trimmedIdentifier.isEmpty }) else {
            return false
        }
        return duplicateIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Contestants") {
                    if contestants.isEmpty {
                        ContentUnavailableView(
                            "No contestants",
                            systemImage: "person.2",
                            description: Text("Add contestants to configure the season.")
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach($contestants) { contestant in
                            ContestantEditorRow(
                                contestant: contestant,
                                isDuplicateId: duplicateIds.contains(contestant.wrappedValue.normalizedIdentifier)
                            )
                        }
                        .onDelete(perform: deleteContestants)
                        .onMove(perform: moveContestants)
                    }
                } footer: {
                    Text("Identifiers are used for scoring and should remain stable once picks are recorded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        withAnimation(.easeInOut) {
                            contestants.append(ContestantDraft())
                        }
                    } label: {
                        Label("Add contestant", systemImage: "plus.circle.fill")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .animation(.easeInOut, value: contestants)
            .navigationTitle("Manage Contestants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = contestants.map { $0.makeContestant() }
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!hasValidContestants)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }

    private func deleteContestants(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            contestants.remove(atOffsets: offsets)
        }
    }

    private func moveContestants(from source: IndexSet, to destination: Int) {
        contestants.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview("Manage Contestants Sheet") {
    ManageContestantsSheet(contestants: AppState.preview.store.config.contestants) { _ in }
}

private struct ContestantEditorRow: View {
    @Binding var contestant: ContestantDraft
    var isDuplicateId: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Display name", text: Binding(
                get: { contestant.name },
                set: { newValue in contestant.updateName(newValue) }
            ))
            .textContentType(.name)

            TextField("Identifier", text: Binding(
                get: { contestant.identifier },
                set: { newValue in contestant.updateIdentifier(newValue) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            TextField("Tribe (optional)", text: Binding(
                get: { contestant.tribe },
                set: { contestant.tribe = $0 }
            ))

            if contestant.trimmedName.isEmpty {
                validationMessage("Name is required")
            }

            if contestant.trimmedIdentifier.isEmpty {
                validationMessage("Identifier is required")
            } else if isDuplicateId {
                validationMessage("Identifier must be unique")
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func validationMessage(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.red)
    }
}

private struct ContestantDraft: Identifiable, Equatable {
    let id: UUID
    private(set) var hasCustomIdentifier: Bool

    var identifier: String
    var name: String
    var tribe: String

    init(id: UUID = UUID(), identifier: String = "", name: String = "", tribe: String = "", hasCustomIdentifier: Bool = false) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.tribe = tribe
        self.hasCustomIdentifier = hasCustomIdentifier
    }

    init(_ contestant: Contestant) {
        self.init(
            identifier: contestant.id,
            name: contestant.name,
            tribe: contestant.tribe ?? "",
            hasCustomIdentifier: true
        )
    }

    mutating func updateName(_ newValue: String) {
        name = newValue
        guard !hasCustomIdentifier else { return }
        identifier = Self.slug(from: newValue)
    }

    mutating func updateIdentifier(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        identifier = newValue
        hasCustomIdentifier = !trimmed.isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedIdentifier: String {
        trimmedIdentifier.lowercased()
    }

    var trimmedTribe: String? {
        let trimmed = tribe.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeContestant() -> Contestant {
        Contestant(id: trimmedIdentifier, name: trimmedName, tribe: trimmedTribe)
    }

    private static func slug(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = text.lowercased().components(separatedBy: allowed.inverted)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: "_")
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

    func handlePhaseSave(_ phase: PickPhase) {
        if let index = app.phases.firstIndex(where: { $0.id == phase.id }) {
            guard !app.hasPhaseEverBeenActive(phase.id) else { return }
            app.phases[index] = phase
        } else {
            app.phases.append(phase)
        }

        if app.activePhaseId == phase.id {
            app.activePhaseId = nil
        }
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
    @State private var categoryBeingEdited: CategoryDraft?
    @State private var isPresetListExpanded = false
    @State private var availablePresets: [CategoryPreset]
    @State private var presetUsageByCategoryID: [CategoryDraft.ID: CategoryPreset.ID]

    private let phase: PickPhase?
    var onSave: (PickPhase) -> Void

    init(phase: PickPhase? = nil, onSave: @escaping (PickPhase) -> Void) {
        self.phase = phase
        self.onSave = onSave
        let initialCategories = phase?.categories.map(CategoryDraft.init) ?? []
        let presetState = Self.initialPresetState(for: initialCategories)
        _phaseName = State(initialValue: phase?.name ?? "")
        _categories = State(initialValue: initialCategories)
        _availablePresets = State(initialValue: presetState.availablePresets)
        _presetUsageByCategoryID = State(initialValue: presetState.usage)
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
                            } label: {
                                CategoryRow(category: category)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        categoryBeingEdited = CategoryDraft()
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                    }

                    DisclosureGroup(isExpanded: $isPresetListExpanded) {
                        VStack(spacing: 8) {
                            if availablePresets.isEmpty {
                                Text("All presets have been added")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity)
                            } else {
                                ForEach(Array(availablePresets.enumerated()), id: \.element.id) { index, preset in
                                    Button {
                                        addCategory(from: preset)
                                    } label: {
                                        CategoryPresetRow(preset: preset)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)

                                    if index < availablePresets.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        .animation(.easeInOut, value: availablePresets)
                    } label: {
                        Label("Category presets", systemImage: "square.grid.2x2")
                    }
                }
            }
            .animation(.easeInOut, value: categories)
            .navigationTitle(phase == nil ? "Create Phase" : "Modify Phase")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $categoryBeingEdited, onDismiss: {
                categoryBeingEdited = nil
            }) { category in
                let isExistingCategory = categories.contains(where: { $0.id == category.id })
                CategoryEditorSheet(category: category, isEditingExisting: isExistingCategory) { category in
                    if let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[index] = category
                        updatePresetUsage(for: category)
                    } else {
                        withAnimation(.easeInOut) {
                            categories.append(category)
                        }
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

private extension CreatePhaseSheet {
    func addCategory(from preset: CategoryPreset) {
        let newCategory = preset.makeDraft()
        presetUsageByCategoryID[newCategory.id] = preset.id
        withAnimation(.easeInOut) {
            categories.append(newCategory)
            availablePresets = availablePresets.filter { $0.id != preset.id }
            isPresetListExpanded = false
        }
    }

    func removeCategory(_ category: CategoryDraft) {
        withAnimation(.easeInOut) {
            categories.removeAll { $0.id == category.id }
        }

        guard let presetID = presetUsageByCategoryID.removeValue(forKey: category.id),
              let preset = CategoryPreset.all.first(where: { $0.id == presetID })
        else { return }

        withAnimation(.easeInOut) {
            availablePresets = sortPresets(availablePresets + [preset])
        }
    }

    func updatePresetUsage(for category: CategoryDraft) {
        guard let presetID = presetUsageByCategoryID[category.id],
              let preset = CategoryPreset.all.first(where: { $0.id == presetID })
        else { return }

        if Self.matchesPreset(category, preset: preset) {
            return
        }

        presetUsageByCategoryID.removeValue(forKey: category.id)

        withAnimation(.easeInOut) {
            availablePresets = sortPresets(availablePresets + [preset])
        }
    }

    static func initialPresetState(for categories: [CategoryDraft]) -> (availablePresets: [CategoryPreset], usage: [CategoryDraft.ID: CategoryPreset.ID]) {
        var usage: [CategoryDraft.ID: CategoryPreset.ID] = [:]

        for category in categories {
            if let preset = matchingPreset(for: category) {
                usage[category.id] = preset.id
            }
        }

        let usedPresetIDs = Set(usage.values)
        let availablePresets = CategoryPreset.all.filter { !usedPresetIDs.contains($0.id) }

        return (availablePresets, usage)
    }

    static func matchingPreset(for category: CategoryDraft) -> CategoryPreset? {
        CategoryPreset.all.first { matchesPreset(category, preset: $0) }
    }

    static func matchesPreset(_ category: CategoryDraft, preset: CategoryPreset) -> Bool {
        normalize(columnId: category.columnId) == normalize(columnId: preset.columnId)
    }

    static func normalize(columnId: String) -> String {
        columnId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    func sortPresets(_ presets: [CategoryPreset]) -> [CategoryPreset] {
        let order = Self.presetOrder
        return presets.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    private static let presetOrder: [CategoryPreset.ID: Int] = {
        var order: [CategoryPreset.ID: Int] = [:]
        for (index, preset) in CategoryPreset.all.enumerated() {
            order[preset.id] = index
        }
        return order
    }()
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
                Text("Column ID: \(category.columnId.isEmpty ? "COL" : category.columnId)")

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

private struct CategoryPresetRow: View {
    let preset: CategoryPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Column ID: \(preset.columnId.isEmpty ? "COL" : preset.columnId)")

                Text("Total picks: \(preset.totalPicks)")

                if let points = preset.pointsPerCorrectPick {
                    Text("Points per correct pick: \(points)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if preset.isLocked {
                Text("Locked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CategoryDraft
    @State private var pointsInput: String

    private let isEditingExisting: Bool
    var onSave: (CategoryDraft) -> Void

    init(category: CategoryDraft, isEditingExisting: Bool, onSave: @escaping (CategoryDraft) -> Void) {
        var initialDraft = category
        initialDraft.totalPicks = max(1, min(initialDraft.totalPicks, 5))

        _draft = State(initialValue: initialDraft)
        _pointsInput = State(initialValue: initialDraft.pointsPerCorrectPick.map(String.init) ?? "")
        self.isEditingExisting = isEditingExisting
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category name", text: $draft.name)

                    TextField("Column ID", text: Binding(
                        get: { draft.columnId },
                        set: { newValue in
                            let allowed = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                            draft.columnId = String(allowed.prefix(4))
                        }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total picks")
                            .font(.callout)
                            .fontWeight(.semibold)

                        Picker("Total picks", selection: $draft.totalPicks) {
                            ForEach(1...5, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                    }

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
            .navigationTitle(isEditingExisting ? "Edit Category" : "Add Category")
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

        categoryToSave.columnId = sanitizedColumnId(
            from: draft.columnId,
            fallbackName: categoryToSave.name
        )

        onSave(categoryToSave)
        dismiss()
    }

    private func sanitizedColumnId(from input: String, fallbackName: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(4)).uppercased()
        }

        let components = fallbackName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        let abbreviation = components
            .compactMap { $0.first }
            .prefix(4)

        if !abbreviation.isEmpty {
            return abbreviation.map(String.init).joined().uppercased()
        }

        let condensed = fallbackName.replacingOccurrences(of: " ", with: "")
        if !condensed.isEmpty {
            return String(condensed.prefix(4)).uppercased()
        }

        return "COL"
    }
}

private struct SelectPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [PickPhase]
    let currentPhaseID: PickPhase.ID?
    let lockedPhaseIDs: Set<PickPhase.ID>
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
                                isEditable: !lockedPhaseIDs.contains(phase.id),
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
            .navigationTitle("Select Phase to Modify")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
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

            for category in insertableCategories {
                let winners = existingResult.winners(for: category.id)
                if !winners.isEmpty {
                    initialSelections[category.id] = Set(winners)
                }
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

        for category in insertableCategories {
            let winners = sortedSelection(for: category)
            result.setWinners(winners, for: category.id)

            if category.matchesImmunityCategory {
                result.immunityWinners = winners
            }

            if category.matchesVotedOutCategory {
                result.votedOut = winners
            }
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
        contestants: AppState.preview.store.config.contestants,
        episodeId: 1,
        existingResult: EpisodeResult(id: 1, immunityWinners: [], votedOut: []),
        onSave: { _ in }
    )
}

private struct PhaseRow: View {
    let phase: PickPhase
    let isActive: Bool
    let isEditable: Bool
    let onActivate: (PickPhase) -> Void
    let onModify: (PickPhase) -> Void
    let onDelete: (PickPhase) -> Void

    var body: some View {
        Button {
            guard isEditable else { return }
            onModify(phase)
        } label: {
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

                    if !isEditable {
                        LockPill(text: "Cannot be modified")
                    }
                }

                if !phase.categories.isEmpty {
                    Text("Categories: \(phase.categories.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
