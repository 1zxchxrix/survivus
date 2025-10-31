import SwiftUI

struct CreatePhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phaseName: String
    @State private var categories: [CategoryDraft]
    @State private var categoryBeingEdited: CategoryDraft?
    @State private var isPresetListExpanded = true
    @State private var availablePresets: [CategoryPreset]
    @State private var presetUsageByCategoryID: [CategoryDraft.ID: CategoryPreset.ID]
    @State private var editMode: EditMode = .inactive

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
                                guard editMode != .active else { return }
                                categoryBeingEdited = category
                            } label: {
                                CategoryRow(category: category)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 1)
                                    .onEnded { _ in
                                        guard editMode != .active else { return }
                                        withAnimation(.easeInOut) {
                                            editMode = .active
                                        }
                                    }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveCategories)
                    }
                }

                Section {
                    Button {
                        categoryBeingEdited = CategoryDraft()
                    } label: {
                        Label("Custom category", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
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
                                            .frame(maxWidth: .infinity, alignment: .leading)
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
            .environment(\.editMode, $editMode)
            .navigationTitle(phase == nil ? "Create Phase" : "Modify Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode == .active {
                        Button("Done") {
                            withAnimation(.easeInOut) {
                                editMode = .inactive
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: savePhase)
                        .fontWeight(.semibold)
                }
            }
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
        }
    }
}

private extension CreatePhaseSheet {
    func savePhase() {
        let trimmedName = phaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phaseNameToSave = trimmedName.isEmpty ? "Untitled Phase" : trimmedName
        let newPhase = PickPhase(
            id: phase?.id ?? UUID(),
            name: phaseNameToSave,
            categories: categories.map { PickPhase.Category($0) }
        )
        onSave(newPhase)
        dismiss()
    }

    func addCategory(from preset: CategoryPreset) {
        let newCategory = preset.makeDraft()
        presetUsageByCategoryID[newCategory.id] = preset.id
        withAnimation(.easeInOut) {
            categories.append(newCategory)
            availablePresets = availablePresets.filter { $0.id != preset.id }
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

    func moveCategories(from source: IndexSet, to destination: Int) {
        var updatedCategories = categories
        updatedCategories.move(fromOffsets: source, toOffset: destination)

        withAnimation(.easeInOut) {
            categories = updatedCategories
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Column ID: \(category.columnId.isEmpty ? "COL" : category.columnId)")

                Text("Total picks: \(category.totalPicks)")

                if category.usesWager {
                    Text("Wager: \(category.wagerPoints.map { "±\($0)" } ?? "—")")
                } else {
                    Text("Points per correct pick: \(category.pointsPerCorrectPick.map(String.init) ?? "—")")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if category.autoScoresRemainingContestants || category.isLocked {
                HStack(spacing: 8) {
                    if category.autoScoresRemainingContestants {
                        StatusPill(text: "Auto-score")
                    }

                    if category.isLocked {
                        StatusPill(text: "Locked")
                    }
                }
            }
        }
    }
}

private struct CategoryPresetRow: View {
    let preset: CategoryPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.name)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Column ID: \(preset.columnId.isEmpty ? "COL" : preset.columnId)")

                Text("Total picks: \(preset.totalPicks)")

                if let wager = preset.wagerPoints {
                    Text("Wager: ±\(wager)")
                } else if let points = preset.pointsPerCorrectPick {
                    Text("Points per correct pick: \(points)")
                } else {
                    Text("Points per correct pick: —")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if preset.autoScoresRemainingContestants || preset.isLocked {
                HStack(spacing: 8) {
                    if preset.autoScoresRemainingContestants {
                        StatusPill(text: "Auto-score")
                    }

                    if preset.isLocked {
                        StatusPill(text: "Locked")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CategoryDraft
    @State private var pointsInput: String
    @State private var wagerInput: String
    @State private var scoringMode: ScoringMode

    private let isEditingExisting: Bool
    var onSave: (CategoryDraft) -> Void

    init(category: CategoryDraft, isEditingExisting: Bool, onSave: @escaping (CategoryDraft) -> Void) {
        var initialDraft = category
        initialDraft.totalPicks = max(1, min(initialDraft.totalPicks, 5))

        _draft = State(initialValue: initialDraft)
        _pointsInput = State(initialValue: initialDraft.pointsPerCorrectPick.map(String.init) ?? "")
        _wagerInput = State(initialValue: initialDraft.wagerPoints.map(String.init) ?? "")
        _scoringMode = State(initialValue: initialDraft.usesWager ? .wager : .normal)
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

                }

                Section("Scoring") {
                    Picker("Scoring mode", selection: $scoringMode) {
                        Text("Normal").tag(ScoringMode.normal)
                        Text("Wager").tag(ScoringMode.wager)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scoringMode) { mode in
                        let isWager = mode == .wager
                        draft.usesWager = isWager
                        if isWager {
                            pointsInput = ""
                            draft.pointsPerCorrectPick = nil
                            draft.autoScoresRemainingContestants = false
                        } else {
                            wagerInput = ""
                            draft.wagerPoints = nil
                        }
                    }

                    if scoringMode == .wager {
                        TextField("Wager points", text: Binding(
                            get: { wagerInput },
                            set: { newValue in
                                let filtered = newValue.filter(\.isNumber)
                                wagerInput = filtered
                                draft.wagerPoints = filtered.isEmpty ? nil : Int(filtered)
                            }
                        ))
                        .keyboardType(.numberPad)
                    } else {
                        TextField("Points per correct pick", text: Binding(
                            get: { pointsInput },
                            set: { newValue in
                                let filtered = newValue.filter(\.isNumber)
                                pointsInput = filtered
                                draft.pointsPerCorrectPick = filtered.isEmpty ? nil : Int(filtered)
                            }
                        ))
                        .keyboardType(.numberPad)

                        Toggle("Auto-score", isOn: $draft.autoScoresRemainingContestants)
                        Text("Will score allotted points for every contestant not voted out.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Toggle("Lock category", isOn: $draft.isLocked)
                    Text("These picks will not be changeable for the entire phase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            .navigationTitle(isEditingExisting ? "Edit Category" : "Custom Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", action: saveCategory)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveCategory() {
        var categoryToSave = draft

        if scoringMode == .wager {
            if let value = Int(wagerInput), !wagerInput.isEmpty {
                categoryToSave.wagerPoints = value
            } else {
                categoryToSave.wagerPoints = nil
            }
            categoryToSave.pointsPerCorrectPick = nil
            categoryToSave.autoScoresRemainingContestants = false
            categoryToSave.usesWager = true
        } else {
            if let value = Int(pointsInput), !pointsInput.isEmpty {
                categoryToSave.pointsPerCorrectPick = value
            } else {
                categoryToSave.pointsPerCorrectPick = nil
            }
            categoryToSave.wagerPoints = nil
            categoryToSave.usesWager = false
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

    private enum ScoringMode: String, CaseIterable, Identifiable {
        case normal
        case wager

        var id: String { rawValue }
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

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}
