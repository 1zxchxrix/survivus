import SwiftUI

struct InsertResultsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let phase: PickPhase
    let contestants: [Contestant]
    let episodeId: Int
    let existingResult: EpisodeResult?
    let onSave: (EpisodeResult) -> Void

    @State private var selections: [PickPhase.Category.ID: Set<String>]
    @State private var pendingResult: EpisodeResult?

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
                        pendingResult = buildEpisodeResult()
                    }
                    .disabled(insertableCategories.isEmpty || contestants.isEmpty)
                }
            }
        }
        .alert(item: $pendingResult) { result in
            Alert(
                title: Text("Submit Results?"),
                message: Text(confirmationMessage(for: result)),
                primaryButton: .default(Text("Submit")) {
                    onSave(result)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .presentationDetents([.fraction(0.85)])
        .presentationCornerRadius(28)
    }

    private var insertableCategories: [PickPhase.Category] {
        phase.categories.filter { !$0.isLocked && !$0.matchesRemainCategory }
    }

    @ViewBuilder
    private func categoryCard(for category: PickPhase.Category) -> some View {
        let title = displayTitle(for: category)
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
        var result = existingResult ?? EpisodeResult(id: episodeId, immunityWinners: [], votedOut: [], phaseId: phase.id)
        result.phaseId = phase.id

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

    private func confirmationMessage(for result: EpisodeResult) -> String {
        let categorySummaries = insertableCategories.compactMap { category -> String? in
            let winners = result.winners(for: category.id)
            guard !winners.isEmpty else { return nil }

            let names = winners.map { contestantName(for: $0) ?? $0 }

            let title = displayTitle(for: category)
            return "\(title): \(names.joined(separator: ", "))"
        }

        if categorySummaries.isEmpty {
            return "No contestants were selected for this week's results."
        }

        return categorySummaries.joined(separator: "\n\n")
    }

    private func contestantName(for id: String) -> String? {
        guard let fullName = contestants.first(where: { $0.id == id })?.name else {
            return nil
        }

        if let firstName = fullName.split(whereSeparator: { $0.isWhitespace }).first {
            return String(firstName)
        }

        return fullName
    }

    private func displayTitle(for category: PickPhase.Category) -> String {
        let displayName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return displayName.isEmpty ? "Untitled Category" : displayName
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
