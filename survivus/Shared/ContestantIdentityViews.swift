import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Displays a contestant's circular avatar using the image that matches the contestant identifier.
struct ContestantAvatar: View {
    @Environment(\.votedOutContestantIDs) private var votedOutContestantIDs

    let contestant: Contestant
    var size: CGFloat = 28

    private var isVotedOut: Bool { votedOutContestantIDs.contains(contestant.id) }

    var body: some View {
        Group {
            if let url = contestant.avatarURL {
                StorageAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    fallbackAvatar
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .grayscale(isVotedOut ? 1 : 0)
        .opacity(isVotedOut ? 0.45 : 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallbackAvatar: some View {
        if let image = loadImage(named: contestant.id) {
            image
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.25)
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage(named: String) -> Image? {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: named) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
}

#Preview("ContestantNameLabel") {
    VStack(alignment: .leading, spacing: 12) {
        ContestantNameLabel(contestant: Contestant(id: "courtney_yates", name: "Courtney Yates"))
        ContestantNameLabel(contestant: Contestant(id: "john_cochran", name: "John Cochran"), avatarSize: 30, font: .title3)
    }
    .padding()
}
