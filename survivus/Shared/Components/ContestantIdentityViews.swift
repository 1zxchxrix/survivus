import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Displays a contestant's circular avatar using the image that matches the contestant identifier.
struct ContestantAvatar: View {
    let imageName: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let image = loadImage(named: imageName) {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
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

/// Convenience view that displays a contestant avatar beside their name.
struct ContestantNameLabel: View {
    let contestant: Contestant
    var avatarSize: CGFloat = 24
    var font: Font = .body

    var body: some View {
        HStack(spacing: 8) {
            ContestantAvatar(imageName: contestant.id, size: avatarSize)
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
