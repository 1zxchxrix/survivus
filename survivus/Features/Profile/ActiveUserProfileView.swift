import SwiftUI

struct ActiveUserProfileView: View {
    @EnvironmentObject private var authentication: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss

    let user: UserProfile

    var body: some View {
        List {
            profileSection

            Section {
                Button(role: .destructive) {
                    authentication.signOut()
                    dismiss()
                } label: {
                    Text("Sign Out")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileSection: some View {
        Section {
            VStack(spacing: 16) {
                Group {
                    if let url = user.avatarURL {
                        StorageAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            avatarPlaceholder(size: 120)
                        }
                    } else if let assetName = user.avatarAssetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        avatarPlaceholder(size: 120)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(radius: 8)

                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    NavigationStack {
        ActiveUserProfileView(
            user: UserProfile(
                id: "u1",
                displayName: "Zac",
                avatarAssetName: "zac",
                avatarURL: URL(string: "gs://survivus1514.firebasestorage.app/users/zac.png")
            )
        )
            .environmentObject(AuthenticationViewModel())
    }
}

private func avatarPlaceholder(size: CGFloat) -> some View {
    Image(systemName: "person.fill")
        .resizable()
        .scaledToFit()
        .padding(size * 0.2)
        .foregroundStyle(.secondary)
}
