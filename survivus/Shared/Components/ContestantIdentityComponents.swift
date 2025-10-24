import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Convenience view that displays a contestant avatar beside their name.
struct ContestantNameLabel: View {
    let contestant: Contestant
    var avatarSize: CGFloat = 24
    var font: Font = .body

    init(contestant: Contestant, avatarSize: CGFloat = 24, font: Font = .body) {
        self.contestant = contestant
        self.avatarSize = avatarSize
        self.font = font
    }

    var body: some View {
        HStack(spacing: 8) {
            ContestantAvatar(contestant: contestant, size: avatarSize)
            Text(contestant.name)
                .font(font)
                .foregroundStyle(.primary)
        }
    }
}

#Preview("ContestantNameLabel") {
    VStack(alignment: .leading, spacing: 12) {
        ContestantNameLabel(contestant: Contestant(id: "courtney_yates", name: "Courtney Yates"))
        ContestantNameLabel(contestant: Contestant(id: "john_cochran", name: "John Cochran"), avatarSize: 30, font: .title3)
    }
    .padding()
}
