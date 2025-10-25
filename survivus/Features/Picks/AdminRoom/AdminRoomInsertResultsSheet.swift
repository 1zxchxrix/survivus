import SwiftUI

struct InsertResultsSheet: View {
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

        let insertableCategories = phase.categories.filter { !$0.isLocked && !$0.matchesRemainCategory }

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
        phase.categories.filter { !$0.isLocked && !$0.matchesRemainCategory }
    }

    @ViewBuilder
    private func categoryCard(for category: PickPhase.Category) -> some View {
        let displayName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = displayName.isEmpty ? "Untitled Category" : displayName
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                if category.isLocked {
                    LockPill(text: "Locked")
                }
            }

            Text("Select all contestants that match the result for this category.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LimitedMultiSelect(
                all: contestants,
                selection: binding(for: category),
                max: nil,
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
