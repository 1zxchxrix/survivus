import SwiftUI

/// A compact pill-shaped label that communicates a locked state in the UI.
///
/// The pill defaults to the text "Locked", but you can supply a custom message
/// to indicate why the surrounding content is unavailable.
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

#Preview("LockPill") {
    VStack(spacing: 12) {
        LockPill()
        LockPill(text: "Locked for Episode 3")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
