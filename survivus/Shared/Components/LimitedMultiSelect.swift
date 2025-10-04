import SwiftUI

/// A grid-based multi-select control that limits how many contestants can be chosen.
///
/// Provide the complete list of contestants with a binding to the set of selected
/// contestant identifiers. The view enforces the `max` limit and optionally allows
/// disabling user interaction.
struct LimitedMultiSelect: View {
    let all: [Contestant]
    @Binding var selection: Set<String>
    let max: Int
    var disabled: Bool = false

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 96), spacing: 16, alignment: .top)
    ]

    private var uniqueContestants: [Contestant] {
        var seen = Set<String>()
        return all.filter { contestant in
            guard !seen.contains(contestant.id) else { return false }
            seen.insert(contestant.id)
            return true
        }
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
            ForEach(uniqueContestants, id: \.id) { contestant in
                Button {
                    toggleSelection(for: contestant.id)
                } label: {
                    selectionLabel(
                        for: contestant.id,
                        name: contestant.name,
                        isSelected: isSelected(contestant.id)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .opacity(disabled ? 0.6 : 1)
            }
        }
    }

    private func isSelected(_ id: String) -> Bool {
        normalizedSelection.contains(id)
    }

    private func toggleSelection(for id: String) {
        guard !disabled else { return }

        if isSelected(id) {
            selection = selectionRemovingNormalizedMatches(of: id)
        } else if normalizedSelection.count < max {
            selection = selectionRemovingNormalizedMatches(of: id)
            selection.insert(id)
        }
    }

    private func selectionRemovingNormalizedMatches(of id: String) -> Set<String> {
        Set(
            selection.filter { element in
                element.trimmingCharacters(in: .whitespacesAndNewlines) != id
            }
        )
    }

    @ViewBuilder
    private func selectionLabel(for id: String, name: String, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ContestantAvatar(imageName: id, size: 72)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 26, height: 26)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    .offset(x: 4, y: 4)
                }
            }

            Text(name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
        )
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
