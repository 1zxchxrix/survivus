import SwiftUI

struct AdminRoomView: View {
    var body: some View {
        Text("Admin Room")
            .font(.title)
            .fontWeight(.semibold)
            .padding()
            .navigationTitle("Admin Room")
    }
}

#Preview {
    NavigationStack {
        AdminRoomView()
    }
}
