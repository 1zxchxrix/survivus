import SwiftUI

// MARK: - Reusable UI

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
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        Text(contestant.name).lineLimit(1)
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

struct LockPill: View {
    var text: String = "Locked"

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.red.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Utilities

func picksLocked(for episode: Episode?) -> Bool {
    guard let episode else { return true }
    // Demo lock: disable once airDate has passed
    return Date() >= episode.airDate
}
