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
                Image(user.avatarAssetName)
                    .resizable()
                    .scaledToFill()
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
        ActiveUserProfileView(user: UserProfile(id: "u1", displayName: "Zac", avatarAssetName: "zac"))
            .environmentObject(AuthenticationViewModel())
    }
}
