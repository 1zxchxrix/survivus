import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
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

/// Convenience view that displays a contestant avatar beside their name.
struct ContestantNameLabel: View {
    let contestant: Contestant
    var avatarSize: CGFloat = 24
    var font: Font = .body

    var body: some View {
        HStack(spacing: 8) {
            ContestantAvatar(contestant: contestant, size: avatarSize)
            Text(contestant.name)
                .font(font)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Storage Image Support

struct StorageAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    var transaction: Transaction = Transaction()
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var resolvedURL: URL?

    var body: some View {
        Group {
            if let resolvedURL {
                AsyncImage(url: resolvedURL, transaction: transaction) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .failure:
                        placeholder()
                    case .success(let image):
                        content(image)
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
                    .task(id: url) {
                        resolvedURL = nil
                        guard let url else {
                            return
                        }
                        resolvedURL = await StorageURLResolver.resolvedURL(from: url)
                    }
            }
        }
    }
}

enum StorageURLResolver {
    static func resolvedURL(from url: URL) async -> URL? {
        guard let scheme = url.scheme?.lowercased() else { return url }

        switch scheme {
        case "gs":
            if let directURL = await directDownloadURL(fromGSURL: url) {
                return directURL
            }
            return fallbackDownloadURL(fromGSURL: url)
        default:
            return url
        }
    }

    private static func directDownloadURL(fromGSURL url: URL) async -> URL? {
        #if canImport(FirebaseStorage)
        do {
            return try await Storage.storage().reference(forURL: url.absoluteString).downloadURL()
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func fallbackDownloadURL(fromGSURL url: URL) -> URL? {
        guard let bucket = url.host else { return nil }
        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let encodedPath: String
        if trimmedPath.isEmpty {
            encodedPath = ""
        } else {
            encodedPath = trimmedPath
                .split(separator: "/")
                .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
                .joined(separator: "%2F")
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "firebasestorage.googleapis.com"
        components.path = "/v0/b/\(bucket)/o"
        if !encodedPath.isEmpty {
            components.path.append("/\(encodedPath)")
        }
        components.queryItems = [URLQueryItem(name: "alt", value: "media")]
        return components.url
    }
}

#Preview("ContestantNameLabel") {
    VStack(alignment: .leading, spacing: 12) {
        ContestantNameLabel(contestant: Contestant(id: "courtney_yates", name: "Courtney Yates"))
        ContestantNameLabel(contestant: Contestant(id: "john_cochran", name: "John Cochran"), avatarSize: 30, font: .title3)
    }
    .padding()
}
