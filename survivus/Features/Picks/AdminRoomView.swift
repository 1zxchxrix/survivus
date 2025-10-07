import SwiftUI

struct AdminRoomView: View {
    @EnvironmentObject var app: AppState
    @State private var phases: [AdminPhase] = AdminPhase.preconfiguredPhases
    @State private var currentPhase: AdminPhase? = AdminPhase.preconfiguredPhases.first
    @State private var isPresentingCreatePhase = false
    @State private var isPresentingSelectPhase = false
    @State private var isPresentingStartWeek = false
    @State private var phaseBeingEdited: AdminPhase?
    @State private var phaseForInsertingResults: AdminPhase?
    @State private var selectedPhaseForNewWeekID: AdminPhase.ID?

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
                    if let phase = currentPhase, !phase.categories.isEmpty {
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
                Button("Select Current Phase") {
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
                    currentPhase = phase
                    isPresentingSelectPhase = false
                },
                onModify: { phase in
                    phaseBeingEdited = phase
                    isPresentingSelectPhase = false
                    isPresentingCreatePhase = true
                },
                onDelete: { phase in
                    phases.removeAll { $0.id == phase.id }
                    if currentPhase?.id == phase.id {
                        currentPhase = nil
                    }
                }
            )
        }
        .sheet(isPresented: $isPresentingCreatePhase, onDismiss: {
            phaseBeingEdited = nil
        }) {
            CreatePhaseSheet(phase: phaseBeingEdited) { phase in
                if let index = phases.firstIndex(where: { $0.id == phase.id }) {
                    phases[index] = phase
                } else {
                    phases.append(phase)
                }

                if currentPhase?.id == phase.id {
                    currentPhase = phase
                } else if currentPhase == nil {
                    currentPhase = phase
                }
            }
            .presentationDetents([.fraction(0.8)])
            .presentationCornerRadius(28)
        }
        .sheet(item: $phaseForInsertingResults) { phase in
            InsertResultsSheet(phase: phase, contestants: app.store.config.contestants)
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
        guard let phase = currentPhase else { return false }
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

    func startNewWeek(activating phase: AdminPhase) {
        let nextWeekId = (app.store.results.map(\.id).max() ?? 0) + 1
        let newResult = EpisodeResult(id: nextWeekId, immunityWinners: [], votedOut: [])
        app.store.results.append(newResult)
        currentPhase = phase
    }
}

private struct StartWeekSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [AdminPhase]
    let onStart: (AdminPhase) -> Void

    @State private var selectedPhaseID: AdminPhase.ID?

    init(phases: [AdminPhase], selectedPhaseID: AdminPhase.ID?, onStart: @escaping (AdminPhase) -> Void) {
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

    private let phase: AdminPhase?
    var onSave: (AdminPhase) -> Void

    init(phase: AdminPhase? = nil, onSave: @escaping (AdminPhase) -> Void) {
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.name.isEmpty ? "Untitled Category" : category.name)
                                        .font(.headline)

                                    HStack {
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
                    let newPhase = AdminPhase(
                        id: phase?.id ?? UUID(),
                        name: phaseNameToSave,
                        categories: categories.map { AdminPhase.Category($0) }
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

private struct SelectPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phases: [AdminPhase]
    let currentPhaseID: AdminPhase.ID?
    let onActivate: (AdminPhase) -> Void
    let onModify: (AdminPhase) -> Void
    let onDelete: (AdminPhase) -> Void

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
            .navigationTitle("Select Phase")
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

    let phase: AdminPhase
    let contestants: [Contestant]

    @State private var selections: [AdminPhase.Category.ID: Set<String>]

    init(phase: AdminPhase, contestants: [Contestant]) {
        self.phase = phase
        self.contestants = contestants
        _selections = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: phase.categories.map { ($0.id, Set<String>()) }
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if phase.categories.isEmpty {
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

                            ForEach(phase.categories) { category in
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
                    Button("Save") { dismiss() }
                        .disabled(phase.categories.isEmpty || contestants.isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationCornerRadius(28)
    }

    @ViewBuilder
    private func categoryCard(for category: AdminPhase.Category) -> some View {
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

    private func binding(for category: AdminPhase.Category) -> Binding<Set<String>> {
        Binding(
            get: { selections[category.id] ?? Set<String>() },
            set: { selections[category.id] = $0 }
        )
    }
}

#Preview("Insert Results Sheet") {
    InsertResultsSheet(phase: .preview, contestants: AppState().store.config.contestants)
}

private struct PhaseRow: View {
    let phase: AdminPhase
    let isActive: Bool
    let onActivate: (AdminPhase) -> Void
    let onModify: (AdminPhase) -> Void
    let onDelete: (AdminPhase) -> Void

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

            HStack(spacing: 12) {
                Button("Activate") {
                    onActivate(phase)
                }
                .buttonStyle(.borderedProminent)

                Button("Modify") {
                    onModify(phase)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    onDelete(phase)
                } label: {
                    Text("Delete")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}

private struct AdminPhase: Identifiable, Equatable {
    struct Category: Identifiable, Equatable {
        let id: UUID
        var name: String
        var totalPicks: Int
        var pointsPerCorrectPick: Int?
        var isLocked: Bool

        init(
            id: UUID = UUID(),
            name: String,
            totalPicks: Int,
            pointsPerCorrectPick: Int?,
            isLocked: Bool
        ) {
            self.id = id
            self.name = name
            self.totalPicks = totalPicks
            self.pointsPerCorrectPick = pointsPerCorrectPick
            self.isLocked = isLocked
        }

        init(from draft: CategoryDraft) {
            self.init(
                id: draft.id,
                name: draft.name,
                totalPicks: draft.totalPicks,
                pointsPerCorrectPick: draft.pointsPerCorrectPick,
                isLocked: draft.isLocked
            )
        }
    }

    let id: UUID
    var name: String
    var categories: [Category]

    init(id: UUID = UUID(), name: String, categories: [Category]) {
        self.id = id
        self.name = name
        self.categories = categories
    }
}

private extension AdminPhase {
    static let preconfiguredPhases: [AdminPhase] = [
        AdminPhase(
            name: "Pre-merge",
            categories: [
                .init(name: "Mergers", totalPicks: 3, pointsPerCorrectPick: 1, isLocked: true),
                .init(name: "Immunity", totalPicks: 3, pointsPerCorrectPick: 3, isLocked: false),
                .init(name: "Voted out", totalPicks: 3, pointsPerCorrectPick: 3, isLocked: false)
            ]
        ),
        AdminPhase(
            name: "Post-merge",
            categories: [
                .init(name: "Immunity", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false),
                .init(name: "Voted out", totalPicks: 2, pointsPerCorrectPick: 5, isLocked: false)
            ]
        ),
        AdminPhase(
            name: "Finals",
            categories: [
                .init(name: "Carried", totalPicks: 1, pointsPerCorrectPick: 10, isLocked: false),
                .init(name: "Fire", totalPicks: 2, pointsPerCorrectPick: 10, isLocked: false),
                .init(name: "Fire winner", totalPicks: 1, pointsPerCorrectPick: 15, isLocked: false),
                .init(name: "Sole Survivor", totalPicks: 1, pointsPerCorrectPick: 25, isLocked: false)
            ]
        )
    ]

    static var preview: AdminPhase {
        AdminPhase(
            name: "Week 1",
            categories: [
                .init(name: "Immunity", totalPicks: 1, pointsPerCorrectPick: 2, isLocked: false),
                .init(name: "Voted Out", totalPicks: 2, pointsPerCorrectPick: 3, isLocked: false),
                .init(name: "Reward Challenge", totalPicks: 3, pointsPerCorrectPick: nil, isLocked: false),
                .init(name: "Locked Category", totalPicks: 1, pointsPerCorrectPick: nil, isLocked: true)
            ]
        )
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categoryName: String
    @State private var totalPicks: Int
    @State private var pointsPerCorrectPick: Int?
    @State private var lockCategory: Bool

    private let category: CategoryDraft?
    var onSave: (CategoryDraft) -> Void

    init(category: CategoryDraft? = nil, onSave: @escaping (CategoryDraft) -> Void) {
        self.category = category
        self.onSave = onSave
        _categoryName = State(initialValue: category?.name ?? "")
        _totalPicks = State(initialValue: category?.totalPicks ?? 1)
        _pointsPerCorrectPick = State(initialValue: category?.pointsPerCorrectPick)
        _lockCategory = State(initialValue: category?.isLocked ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Category", text: $categoryName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total picks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Total picks", selection: $totalPicks) {
                            ForEach(1...5, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 150)
                    }

                    TextField("Points per correct pick", value: $pointsPerCorrectPick, format: .number)
                        .keyboardType(.numberPad)
                }

                Section {
                    Toggle("Lock category after initial pick", isOn: $lockCategory)
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Modify Category")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let nameToSave = trimmedName.isEmpty ? "Untitled Category" : trimmedName
                    onSave(
                        CategoryDraft(
                            id: category?.id ?? UUID(),
                            name: nameToSave,
                            totalPicks: totalPicks,
                            pointsPerCorrectPick: pointsPerCorrectPick,
                            isLocked: lockCategory
                        )
                    )
                    dismiss()
                } label: {
                    Text(category == nil ? "Add category" : "Save changes")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

private struct CategoryDraft: Identifiable {
    let id: UUID
    var name: String
    var totalPicks: Int
    var pointsPerCorrectPick: Int?
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        totalPicks: Int,
        pointsPerCorrectPick: Int?,
        isLocked: Bool
    ) {
        self.id = id
        self.name = name
        self.totalPicks = totalPicks
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.isLocked = isLocked
    }

    init(from category: AdminPhase.Category) {
        self.init(
            id: category.id,
            name: category.name,
            totalPicks: category.totalPicks,
            pointsPerCorrectPick: category.pointsPerCorrectPick,
            isLocked: category.isLocked
        )
    }
}

private extension AdminPhase.Category {
    init(_ draft: CategoryDraft) {
        self.init(
            id: draft.id,
            name: draft.name,
            totalPicks: draft.totalPicks,
            pointsPerCorrectPick: draft.pointsPerCorrectPick,
            isLocked: draft.isLocked
        )
    }
}
