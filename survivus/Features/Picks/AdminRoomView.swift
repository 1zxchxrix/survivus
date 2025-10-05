import SwiftUI

struct AdminRoomView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Phase: Pre-merge")
                    Text("Current Week: 2")
                }
            }

            Section("Week") {
                Button("Insert Results") {}
                Button("Modify Previous Results") {}
                Button("Start New Week") {}
            }

            Section("Phase") {
                Button("Select Current Phase") {}
                Button("Create New Phase") {}
                Button("Remove Phase") {}
            }
        }
        .navigationTitle("Admin Room")
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
    }
}
