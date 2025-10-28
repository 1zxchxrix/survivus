import SwiftUI

/// A grid-based multi-select control that optionally limits how many contestants can be chosen.
///
/// Provide the complete list of contestants with a binding to the set of selected
/// contestant identifiers. When `max` is provided the view enforces that limit and
/// optionally allows disabling user interaction.
struct LimitedMultiSelect: View {
    
    @Environment(\.votedOutContestantIDs) private var votedOutContestantIDs

    let all: [Contestant]
    @Binding var selection: Set<String>
    var max: Int? = nil
    var disabled: Bool = false

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 96), spacing: 16, alignment: .top)
    ]

    @State private var selectionOrder: [String] = []
    
    private var uniqueContestants: [Contestant] {
        var seen = Set<String>()
        return all.filter { contestant in
            guard !seen.contains(contestant.id) else { return false }
            seen.insert(contestant.id)
            return true
        }
    }

    private var eligibleContestants: [Contestant] {
        uniqueContestants.filter { !votedOutContestantIDs.contains($0.id) }
    }

    private var eligibleContestantIDs: Set<String> {
        Set(eligibleContestants.map(\.id))
    }

    private var normalizedSelection: Set<String> {
        Set(
            selection
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(eligibleContestants, id: \.id) { contestant in
                let currentlySelected = isSelected(contestant.id)
                let currentRank = selectionRank(for: contestant.id)

                Button {
                    toggleSelection(for: contestant.id)
                } label: {
                    selectionLabel(
                        for: contestant,
                        isCurrentlySelected: currentlySelected,
                        selectionRank: currentRank
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
//                .background(
//                    RoundedRectangle(cornerRadius: 12, style: .continuous)
//                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
//                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .opacity(disabled ? 0.6 : 1)
        }
        .onAppear {
            syncSelectionOrder(with: normalizedSelection)
            enforceEligibility()
        }
        .onChange(of: normalizedSelectionSorted) { _ in
            syncSelectionOrder(with: normalizedSelection)
        }
        .onChange(of: votedOutContestantIDs) { _ in
            enforceEligibility()
        }
    }

    private func isSelected(_ id: String) -> Bool {
        normalizedSelection.contains(id)
    }

    private func toggleSelection(for id: String) {
        guard !disabled else { return }

        if isSelected(id) {
            selection = selectionRemovingNormalizedMatches(of: id)
            selectionOrder.removeAll { $0 == id }
        } else if canSelectMore {
            selection = selectionRemovingNormalizedMatches(of: id)
            selection.insert(id)
            selectionOrder.removeAll { $0 == id }
            selectionOrder.append(id)
        }
    }

    private var canSelectMore: Bool {
        guard let max else { return true }
        return normalizedSelection.count < max
    }

    private func selectionRemovingNormalizedMatches(of id: String) -> Set<String> {
        Set(
            selection.filter { element in
                element.trimmingCharacters(in: .whitespacesAndNewlines) != id
            }
        )
    }

    private var normalizedSelectionSorted: [String] {
        normalizedSelection.sorted()
    }

    private func syncSelectionOrder(with selection: Set<String>) {
        var updatedOrder = selectionOrder.filter { selection.contains($0) }
        let orderedIds = eligibleContestants.map(\.id).filter { selection.contains($0) }
        for id in orderedIds where !updatedOrder.contains(id) {
            updatedOrder.append(id)
        }

        if updatedOrder != selectionOrder {
            selectionOrder = updatedOrder
        }
    }

    private func enforceEligibility() {
        let filtered = normalizedSelection.intersection(eligibleContestantIDs)
        guard filtered != normalizedSelection else { return }

        selection = filtered
        selectionOrder.removeAll { !filtered.contains($0) }
    }

    private func selectionRank(for id: String) -> Int? {
        guard let index = selectionOrder.firstIndex(of: id) else { return nil }
        return index + 1
    }

    @ViewBuilder
    private func selectionLabel(for contestant: Contestant, isCurrentlySelected: Bool, selectionRank: Int?) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ContestantAvatar(contestant: contestant, size: 72)
                    .overlay(
                        Circle()
                            .stroke(
                                isCurrentlySelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isCurrentlySelected ? 3 : 1
                            )
                    )

                if let rank = selectionRank {
                    selectionBadge(for: rank)
                        .offset(x: 6, y: -6)
                }
            }

            Text(contestant.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func selectionBadge(for rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 24)

            Text("\(rank)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white)
        }
    }
}

struct LimitedMultiSelect_Previews: PreviewProvider {
    static var previews: some View {
        LimitedMultiSelectPreview()
    }
}

private struct LimitedMultiSelectPreview: View {
    @State private var selection: Set<String> = ["courtney_yates"]
    private let contestants: [Contestant] = [
        Contestant(id: "courtney_yates", name: "Courtney Yates"),
        Contestant(id: "todd_herzog", name: "Todd Herzog"),
        Contestant(id: "boston_rob", name: "Boston Rob"),
        Contestant(id: "russell_hantz", name: "Russell Hantz"),
        Contestant(id: "john_cochran", name: "John Cochran"),
    ]
    
    var body: some View {
        LimitedMultiSelect(
            all: contestants,
            selection: $selection,
            max: 3
        )
        .padding()
    }
}
