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

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(all) { contestant in
                let isSelected = selection.contains(contestant.id)
                Button {
                    guard !disabled else { return }
                    if isSelected {
                        selection.remove(contestant.id)
                    } else if selection.count < max {
                        selection.insert(contestant.id)
                    }
                } label: {
                    VStack(spacing: 12) {
                        ContestantAvatar(imageName: contestant.id, size: 72)
                        Text(contestant.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
                            .padding(10)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }
}

#Preview("LimitedMultiSelect") {
    LimitedMultiSelectPreview()
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
