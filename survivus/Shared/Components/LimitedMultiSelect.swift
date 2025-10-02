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

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
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
                    HStack(spacing: 10) {
                        ContestantAvatar(imageName: contestant.id, size: 32)
                        Text(contestant.name)
                            .lineLimit(1)
                            .font(.subheadline)
                        Spacer(minLength: 4)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
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
