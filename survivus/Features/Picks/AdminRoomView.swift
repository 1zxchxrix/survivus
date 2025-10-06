import SwiftUI

struct AdminRoomView: View {
    @State private var phases: [AdminPhase] = []
    @State private var currentPhase: AdminPhase?
    @State private var isPresentingCreatePhase = false
    @State private var isPresentingSelectPhase = false
    @State private var phaseBeingEdited: AdminPhase?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Phase: \(currentPhase?.name ?? "None")")
                    Text("Current Week: 2")
                }
            }

            Section("Week") {
                Button("Insert Results") {}
                Button("Modify Previous Results") {}
                Button("Start New Week") {}
            }

            Section("Phase") {
                Button("Select Current Phase") {
                    isPresentingSelectPhase = true
                }
                Button("Create New Phase") {
                    phaseBeingEdited = nil
                    isPresentingCreatePhase = true
                }
            }
        }
        .navigationTitle("Admin Room")
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
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
    }
}

private struct CreatePhaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phaseName: String
    @State private var categories: [CategoryDraft]
    @State private var isPresentingAddCategory = false

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
                    }
                }

                Section {
                    Button {
                        isPresentingAddCategory = true
                    } label: {
                        Label("Add category", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Create Phase")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingAddCategory) {
                AddCategorySheet { category in
                    categories.append(category)
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

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var categoryName = ""
    @State private var totalPicks = 1
    @State private var pointsPerCorrectPick: Int? = nil
    @State private var lockCategory = false

    var onAdd: (CategoryDraft) -> Void

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
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(
                        CategoryDraft(
                            name: categoryName,
                            totalPicks: totalPicks,
                            pointsPerCorrectPick: pointsPerCorrectPick,
                            isLocked: lockCategory
                        )
                    )
                    dismiss()
                } label: {
                    Text("Add category")
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
