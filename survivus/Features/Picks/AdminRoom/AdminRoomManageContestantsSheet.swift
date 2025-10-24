import SwiftUI

struct ManageContestantsSheet: View {
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
                Section {
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
                } header: {
                    Text("Contestants")
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
    var avatarAssetName: String?

    init(
        id: UUID = UUID(),
        identifier: String = "",
        name: String = "",
        tribe: String = "",
        avatarAssetName: String? = nil,
        hasCustomIdentifier: Bool = false
    ) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.tribe = tribe
        self.avatarAssetName = avatarAssetName
        self.hasCustomIdentifier = hasCustomIdentifier
    }

    init(_ contestant: Contestant) {
        self.init(
            identifier: contestant.id,
            name: contestant.name,
            tribe: contestant.tribe ?? "",
            avatarAssetName: contestant.avatarAssetName,
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

    var trimmedAvatarAssetName: String? {
        guard let avatarAssetName else { return nil }
        let trimmed = avatarAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func makeContestant() -> Contestant {
        Contestant(
            id: trimmedIdentifier,
            name: trimmedName,
            tribe: trimmedTribe,
            avatarAssetName: trimmedAvatarAssetName ?? trimmedIdentifier
        )
    }

    private static func slug(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = text.lowercased().components(separatedBy: allowed.inverted)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: "_")
    }
}
