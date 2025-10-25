import SwiftUI

struct ScoreDetailsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Score details coming soon.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Score Details")
    }
}

#Preview {
    NavigationStack {
        ScoreDetailsView()
    }
}
